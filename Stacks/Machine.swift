//
//  Machine.swift
//  Stacks
//
//  Created by David Brown on 6/11/14.
//  Copyright (c) 2014 bithead. All rights reserved.
//

import Foundation

enum Cell {
    case Thread(index: Int)
    case Primitive(num: Int)
    case Literal(value: Int)
    case Branch(destinationIndex: Int)
    case ZeroBranch(destinationIndex: Int)
    case Variable(address: Int)
    case Constant(value: Int)

    func description() -> String {
        switch self {
        case let .Thread(index):
            return "Thread(\(index))"
        case let .Primitive(num):
            return "Primitive(\(num))"
        case let .Literal(value):
            return "\(value)"
        case let .Constant(value):
            return "Constant(\(value))"
        case let .Variable(address):
            return "Variable(\(address))"
        default:
            return "?"
        }
    }
}

class Machine {
    var dataStack: Cell[] = []
    var returnStack: Cell[] = []
    var heap: Cell[] = []
    var wordDictionary = Dictionary<String, Int>()
    var instructionPointer = 0
    var exitFlag = false
    var errorFlag = false
    var primitiveTable: (()->Void)[] = []
    var primitiveDictionary = Dictionary<String, Int>()

    init() {
        self.registerPrimitives()
    }

    func registerPrimitive(name:String, _ primitiveClosure: ()->Void) -> Int {
        let index = primitiveTable.endIndex
        self.primitiveDictionary[name] = index
        primitiveTable += primitiveClosure
        return index
    }

    func next() {   // inner interpreter
        var currentItem = heap[instructionPointer++]

        switch currentItem {
        case let .Thread(index):
            returnStack += Cell.Thread(index: instructionPointer)
            instructionPointer = index

        case let .Primitive(num):
            self.primitiveTable[num]()

        case let .Branch(destinationIndex):
            instructionPointer = destinationIndex

        case let .ZeroBranch(destinationIndex):
            switch self.pop() {
            case let .Literal(value):
                if (value == 0) {
                    instructionPointer = destinationIndex
                }
            default:
                self.error()
            }

        case let .Literal(value):
            self.push(currentItem)

        case let .Constant(value):
            self.push(Cell.Literal(value: value))

        case let .Variable(address):
            self.push(Cell.Literal(value: address))

        default:
            println("problem: \(currentItem.description())")
        }
    }

    func error() {
        println("oops.")
        self.dataStack = []
        self.returnStack = []
        self.exitFlag = true
        self.errorFlag = true
    }

    func topOfStack() -> Cell! {
        return self.dataStack[self.dataStack.endIndex - 1]
    }

    func secondOnStack() -> Cell! {
        return self.dataStack[self.dataStack.endIndex - 2]
    }

    func pop() -> Cell {
        let result = self.topOfStack()
        self.dataStack.removeLast()
        return result
    }

    func rpop() -> Cell {
        let result = self.returnStack[self.returnStack.endIndex - 1]
        self.returnStack.removeLast()
        return result
    }

    func push(val: Cell) {
        self.dataStack += val
    }

    func rpush(val: Cell) {
        self.returnStack += val
    }

    func dup() {
        self.push(self.topOfStack())
    }

    func swap() {
        let temp = self.dataStack[self.dataStack.endIndex - 1]
        self.dataStack[self.dataStack.endIndex - 1] = self.dataStack[self.dataStack.endIndex - 2]
        self.dataStack[self.dataStack.endIndex - 2] = temp
    }

    func over() {
        self.push(self.secondOnStack())
    }

    func nip() {
        self.swap()
        self.pop()
    }

    func tuck() {
        self.swap()
        self.over()
    }

    func rot() {
        let temp = self.dataStack[self.dataStack.endIndex - 3]
        self.dataStack[self.dataStack.endIndex - 3] = self.dataStack[self.dataStack.endIndex - 2]
        self.dataStack[self.dataStack.endIndex - 2] = self.dataStack[self.dataStack.endIndex - 1]
        self.dataStack[self.dataStack.endIndex - 1] = temp
    }

    func negrot() {
        let temp = self.dataStack[self.dataStack.endIndex - 1]
        self.dataStack[self.dataStack.endIndex - 1] = self.dataStack[self.dataStack.endIndex - 2]
        self.dataStack[self.dataStack.endIndex - 2] = self.dataStack[self.dataStack.endIndex - 3]
        self.dataStack[self.dataStack.endIndex - 3] = temp
    }

    func toR() {
        self.rpush(self.pop())
    }

    func fromR() {
        self.push(self.rpop())
    }

    func fetchR() {
        self.push(self.returnStack[self.returnStack.endIndex - 1])
    }

    func exitPrim() {
        switch self.rpop() {
        case let .Thread(index):
            instructionPointer = index
        default:
            self.error()
        }
        next()
    }

    func dotsPrim() {
        for i in self.dataStack {
            print("\(i.description()) ")
        }
        self.next()
    }

    func dupPrim() {
        self.dup()
        self.next()
    }

    func dropPrim() {
        self.pop()
        self.next()
    }

    func swapPrim() {
        self.swap()
        self.next()
    }

    func overPrim() {
        self.over()
        self.next()
    }

    func rotPrim() {
        self.rot()
        self.next()
    }

    func negrotPrim() {
        self.negrot()
        self.next()
    }

    func nipPrim() {
        self.nip()
        self.next()
    }

    func tuckPrim() {
        self.tuck()
        self.next()
    }

    func intMathPrimAux(action:(Int, Int)->Int) {
        let b = self.pop()
        let a = self.pop()
        switch a {
        case let .Literal(aValue):
            switch b {
            case let .Literal(bValue):
                self.push(Cell.Literal(value:action(aValue, bValue)))
            default:
                self.error()
            }
        default:
            self.error()
        }
    }

    func addPrim() {
        intMathPrimAux { $0 + $1 }
        self.next()
    }

    func subPrim() {
        intMathPrimAux { $0 - $1 }
        self.next()
    }

    func multPrim() {
        intMathPrimAux { $0 * $1 }
        self.next()
    }

    func divPrim() {
        intMathPrimAux { $0 / $1 }
        self.next()
    }

    func multDivPrim() {
        let c = self.pop()
        intMathPrimAux { $0 * $1 }
        self.push(c)
        intMathPrimAux { $0 / $1 }
        self.next()
    }

    func andPrim() {
        intMathPrimAux { $0 & $1 }
        self.next()
    }

    func orPrim() {
        intMathPrimAux { $0 | $1 }
        self.next()
    }

    func xorPrim() {
        intMathPrimAux { $0 ^ $1 }
        self.next()
    }

    func greaterThanZeroPrim() {
        switch self.pop() {
        case let .Literal(value):
            if value > 0 {
                self.push(Cell.Literal(value: 1))
            } else {
                self.push(Cell.Literal(value: 0))
            }
        default:
            self.error()
        }
        self.next()
    }

    func printTopOfStackPrim() {
        print("\(self.pop().description()) ")
        self.next()
    }

    func fetchPrim() {
        let indexLiteral = self.pop()
        switch indexLiteral {
        case let .Literal(index):
            self.push(self.heap[index])
        default:
            self.error()
        }
    }

    func storePrim() {
        let indexLiteral = self.pop()
        switch indexLiteral {
        case let .Literal(index):
            let value = self.pop()
            self.heap[index] = value
        default:
            self.error()
        }
        self.next()
    }

    func toRPrim() {
        self.toR()
        self.next()
    }

    func fromRPrim() {
        self.fromR()
        self.next()
    }

    func fetchRPrim() {
        self.fetchR()
        self.next()
    }

    func wordsPrim() {
        for (k, v) in self.primitiveDictionary {
            print("\(k) ")
        }
        for (k, v) in self.wordDictionary {
            print("\(k) ")
        }
        self.next()
    }

    func registerPrimitives() {
        self.registerPrimitive(";",     { self.exitPrim() })
        self.registerPrimitive("bye",   { self.exitFlag = true })
        self.registerPrimitive("hello", { println("hello world!") })
        self.registerPrimitive("dup",   { self.dupPrim() })
        self.registerPrimitive("drop",  { self.dropPrim() })
        self.registerPrimitive("swap",  { self.swapPrim() })
        self.registerPrimitive("nip",   { self.nipPrim() })
        self.registerPrimitive("tuck",  { self.tuckPrim() })
        self.registerPrimitive("over",  { self.overPrim() })
        self.registerPrimitive(">r",    { self.toRPrim() })
        self.registerPrimitive("r>",    { self.fromRPrim() })
        self.registerPrimitive("r@",    { self.fetchRPrim() })
        self.registerPrimitive("+",     { self.addPrim() })
        self.registerPrimitive("-",     { self.subPrim() })
        self.registerPrimitive("*",     { self.multPrim() })
        self.registerPrimitive("/",     { self.divPrim() })
        self.registerPrimitive("*/",    { self.multDivPrim() })
        self.registerPrimitive(".",     { self.printTopOfStackPrim() })
        self.registerPrimitive("@",     { self.fetchPrim() })
        self.registerPrimitive("!",     { self.storePrim() })
        self.registerPrimitive("words", { self.wordsPrim() })
        self.registerPrimitive("0<",    { self.greaterThanZeroPrim() })
        self.registerPrimitive("and",   { self.andPrim() })
        self.registerPrimitive("or",    { self.orPrim() })
        self.registerPrimitive("xor",   { self.xorPrim() })
    }

    func mainLoop() {
        while !exitFlag {
            next()
        }
    }

    func cellForName(name:String) -> Cell! {
        if let primIndex = self.primitiveDictionary[name] {
            return Cell.Primitive(num: primIndex)
        } else if let index = self.wordDictionary[name] {
            return Cell.Thread(index: index)
        } else if let value = name.toInt() {
            return Cell.Literal(value: value)
        } else {
            return nil
        }
    }

    func heapIndexForName(name: String) -> Int! {
        return self.wordDictionary[name]
    }

    func createName(name: String) -> Int {
        let nameAddress = self.heap.endIndex
        self.wordDictionary[name] = nameAddress
        return nameAddress
    }

    func registerWord(name: String, words threadedCode:String[]) {
        createName(name)
        heap += Cell.Branch(destinationIndex: heap.endIndex + 1)
        for name in threadedCode {
            heap += cellForName(name)
        }
    }

    func registerConstant(name: String, value: Int) {
        createName(name)
        heap += Cell.Constant(value: value)
    }

    func registerVariable(name: String, initialValue: Int) {
        let address = createName(name)
        heap += Cell.Variable(address: address)
    }

    func executeWord(word: String) -> Bool {
        self.instructionPointer = self.heapIndexForName(word)
        self.mainLoop()
        return !self.errorFlag
    }
}

class ThreadedInterpreter {
    let engine = Machine()

    func test() {
        engine.registerWord("printit",  words:["hello", ";"])
        engine.registerWord("outnum",   words:["dup", ".", ";"])
        engine.registerWord("testmath", words:["1", "outnum", "2", "outnum", "+", ".", ";"])
        engine.registerWord("second",   words:["testmath", "printit", ";"])
        engine.registerWord("first",    words:["words", "second", "bye", ";"])

        // here goes nothing, should print "hello world!"
        //
        engine.executeWord("first")
    }
}