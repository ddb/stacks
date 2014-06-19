//
//  Machine.swift
//  Stacks
//
//  Created by David Brown on 6/11/14.
//  Copyright (c) 2014 bithead. All rights reserved.
//

import Foundation

enum Cell: Printable {
    case Thread(index: Int)
    case Primitive(num: Int)
    case Literal(value: Int)
    case Branch(destinationIndex: Int)
    case ZeroBranch(destinationIndex: Int)
    case Variable(address: Int)
    case Constant(value: Int)

    var description: String {
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
        case let .Branch(address):
            return "Branch(\(address))"
        case let .ZeroBranch(address):
            return "ZeroBranch(\(address))"
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

    func registerPrimitive(name:String, execute primitiveClosure: ()->Void) -> Int {
        let index = self.primitiveTable.endIndex
        self.primitiveDictionary[name] = index
        self.primitiveTable += primitiveClosure
        return index
    }

    func next() {   // inner interpreter
        var currentItem = self.heap[self.instructionPointer++]

        switch currentItem {
        case let .Thread(index):
            self.returnStack += Cell.Thread(index: instructionPointer)
            self.instructionPointer = index

        case let .Primitive(num):
            self.primitiveTable[num]()

        case let .Branch(destinationIndex):
            self.instructionPointer = destinationIndex

        case let .ZeroBranch(destinationIndex):
            switch self.pop() {
            case let .Literal(value):
                if (value == 0) {
                    self.instructionPointer = destinationIndex
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
            println("problem: \(currentItem)")
        }
    }

    func error() {
        println("oops.")
        self.dataStack = []
        self.returnStack = []
        self.exitFlag = true
        self.errorFlag = true
    }

    func mainLoop() {
        while !self.exitFlag {
            self.next()
        }
    }

    func cellForName(name:String) -> Cell! {
        if let PrimitiveIndex = self.primitiveDictionary[name] {
            return Cell.Primitive(num: PrimitiveIndex)
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
        self.createName(name)
        self.heap += Cell.Branch(destinationIndex: self.heap.endIndex + 1)
        for name in threadedCode {
            self.heap += self.cellForName(name)
        }
    }

    func registerConstant(name: String, value: Int) {
        self.createName(name)
        self.heap += Cell.Constant(value: value)
    }

    func registerVariable(name: String, initialValue: Int) {
        let address = self.createName(name)
        self.heap += Cell.Variable(address: address)
    }

    func executeWord(word: String) -> Bool {
        self.instructionPointer = self.heapIndexForName(word)
        self.mainLoop()
        return !self.errorFlag
    }
}

extension Machine { // operations
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
}

extension Machine { // Primitives
    func exitPrimitive() {
        switch self.rpop() {
        case let .Thread(index):
            self.instructionPointer = index
        default:
            self.error()
        }
        self.next()
    }

    func dotsPrimitive() {
        for i in self.dataStack {
            print("\(i) ")
        }
        self.next()
    }

    func dupPrimitive() {
        self.dup()
        self.next()
    }

    func dropPrimitive() {
        self.pop()
        self.next()
    }

    func swapPrimitive() {
        self.swap()
        self.next()
    }

    func overPrimitive() {
        self.over()
        self.next()
    }

    func rotPrimitive() {
        self.rot()
        self.next()
    }

    func negrotPrimitive() {
        self.negrot()
        self.next()
    }

    func nipPrimitive() {
        self.nip()
        self.next()
    }

    func tuckPrimitive() {
        self.tuck()
        self.next()
    }

    func integerMathOperation(action:(lhs:Int, rhs:Int)->Int) {
        let bCell = self.pop()
        let aCell = self.pop()
        switch aCell {
        case let .Literal(a):
            switch bCell {
            case let .Literal(b):
                self.push(Cell.Literal(value:action(lhs:a, rhs:b)))
            default:
                self.error()
            }
        default:
            self.error()
        }
    }

    func addPrimitive() {
        self.integerMathOperation { $0 + $1 }
        self.next()
    }

    func subPrimitive() {
        self.integerMathOperation { $0 - $1 }
        self.next()
    }

    func multPrimitive() {
        self.integerMathOperation { $0 * $1 }
        self.next()
    }

    func divPrimitive() {
        self.integerMathOperation { $0 / $1 }
        self.next()
    }

    func multDivPrimitive() {
        let c = self.pop()
        self.integerMathOperation { $0 * $1 }
        self.push(c)
        self.integerMathOperation { $0 / $1 }
        self.next()
    }

    func andPrimitive() {
        self.integerMathOperation { $0 & $1 }
        self.next()
    }

    func orPrimitive() {
        self.integerMathOperation { $0 | $1 }
        self.next()
    }

    func xorPrimitive() {
        self.integerMathOperation { $0 ^ $1 }
        self.next()
    }

    func greaterThanZeroPrimitive() {
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

    func printTopOfStackPrimitive() {
        print("\(self.pop()) ")
        self.next()
    }

    func fetchPrimitive() {
        let indexLiteral = self.pop()
        switch indexLiteral {
        case let .Literal(index):
            self.push(self.heap[index])
        default:
            self.error()
        }
    }

    func storePrimitive() {
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

    func toRPrimitive() {
        self.toR()
        self.next()
    }

    func fromRPrimitive() {
        self.fromR()
        self.next()
    }

    func fetchRPrimitive() {
        self.fetchR()
        self.next()
    }

    func wordsPrimitive() {
        for (k, v) in self.primitiveDictionary {
            print("\(k) ")
        }
        for (k, v) in self.wordDictionary {
            print("\(k) ")
        }
        self.next()
    }

    func registerPrimitives() {
        self.registerPrimitive(";",     execute:{ self.exitPrimitive() })
        self.registerPrimitive("bye",   execute:{ self.exitFlag = true })
        self.registerPrimitive("hello", execute:{ println("hello world!") })
        self.registerPrimitive("dup",   execute:{ self.dupPrimitive() })
        self.registerPrimitive("drop",  execute:{ self.dropPrimitive() })
        self.registerPrimitive("swap",  execute:{ self.swapPrimitive() })
        self.registerPrimitive("nip",   execute:{ self.nipPrimitive() })
        self.registerPrimitive("tuck",  execute:{ self.tuckPrimitive() })
        self.registerPrimitive("over",  execute:{ self.overPrimitive() })
        self.registerPrimitive(">r",    execute:{ self.toRPrimitive() })
        self.registerPrimitive("r>",    execute:{ self.fromRPrimitive() })
        self.registerPrimitive("r@",    execute:{ self.fetchRPrimitive() })
        self.registerPrimitive("+",     execute:{ self.addPrimitive() })
        self.registerPrimitive("-",     execute:{ self.subPrimitive() })
        self.registerPrimitive("*",     execute:{ self.multPrimitive() })
        self.registerPrimitive("/",     execute:{ self.divPrimitive() })
        self.registerPrimitive("*/",    execute:{ self.multDivPrimitive() })
        self.registerPrimitive(".",     execute:{ self.printTopOfStackPrimitive() })
        self.registerPrimitive("@",     execute:{ self.fetchPrimitive() })
        self.registerPrimitive("!",     execute:{ self.storePrimitive() })
        self.registerPrimitive("words", execute:{ self.wordsPrimitive() })
        self.registerPrimitive("0<",    execute:{ self.greaterThanZeroPrimitive() })
        self.registerPrimitive("and",   execute:{ self.andPrimitive() })
        self.registerPrimitive("or",    execute:{ self.orPrimitive() })
        self.registerPrimitive("xor",   execute:{ self.xorPrimitive() })
    }
}

extension Machine: Printable {
    var description: String {
    var s = ""
        var i = 0
        for c in self.heap {
            s += "\t\(i++):\t\(c)\n"
        }
        return "data: \(self.dataStack)\nreturn: \(self.returnStack)\nheap:\n\(s)"
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

        println("\(engine)")
    }
}