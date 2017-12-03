//
//  Geth.swift
//  breadwallet
//
//  Created by Aaron Voisine on 9/7/17.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import Geth
import BRCore

class GethManager {
    let context: GethContext
    let client: GethEthereumClient
    let address: GethAddress
    let store: Store

    var balance: GethBigInt {
        return try! client.getBalanceAt(context, account: address, number: -1)
    }
    
    var receiveAddress: String {
        return address.getHex()
    }
    private let gasLimit: Int64 = 300000
    init(ethPrivKey: String, store: Store) {
        self.store = store
        context = GethContext()

        if E.isTestnet {
            client = GethEthereumClient("https://ropsten.infura.io/")
        } else {
            client = GethEthereumClient("https://mainnet.infura.io")
        }

        address = autoreleasepool {
            let ks = GethKeyStore(NSTemporaryDirectory(), scryptN:2, scryptP:1)
            var data = CFDataCreateMutable(secureAllocator, MemoryLayout<UInt256>.stride) as Data
            data.count = MemoryLayout<UInt256>.stride
            var key = BRKey(privKey: ethPrivKey)
            data.withUnsafeMutableBytes({ $0.pointee = key!.secret })
            key!.clean()

            let account: GethAccount
            do {
                account = (try ks?.getAccounts().get(0))!
            } catch {
                account = (try! ks?.importECDSAKey(data, passphrase: ethPrivKey))!
            }

            let address = account.getAddress()
            try? ks?.delete(account, passphrase: ethPrivKey)
            return address!

        }
        
        //print("receive address:\(address.getHex())")
        //print("latest block:\(try! client.getBlockByNumber(context, number: -1).getNumber())")
    }

    func maxOutputAmount(toAddress: String) -> GethBigInt {
        return balance
    }

    func createTx(forAmount: GethBigInt, toAddress: String, nonce: Int64) -> GethTransaction {
        let toAddr = GethAddress(fromHex: toAddress)
        let price = try! client.suggestGasPrice(context)
        return GethTransaction(nonce, to: toAddr, amount: forAmount, gasLimit: GethBigInt(gasLimit),
                               gasPrice: price, data: nil)
    }

    var fee: GethBigInt {
        let price = (try! client.suggestGasPrice(context)).getInt64()
        return GethBigInt(price * gasLimit)
    }
    
    func signTx(_ tx: GethTransaction, ethPrivKey: String) -> GethTransaction {
        return autoreleasepool {
            let ks = GethKeyStore(NSTemporaryDirectory(), scryptN:2, scryptP:1)
            var data = CFDataCreateMutable(secureAllocator, MemoryLayout<UInt256>.stride) as Data
            data.count = MemoryLayout<UInt256>.stride
            var key = BRKey(privKey: ethPrivKey)
            data.withUnsafeMutableBytes({ $0.pointee = key!.secret })
            key!.clean()
            let account = try! ks?.importECDSAKey(data, passphrase: ethPrivKey)
            try? ks?.unlock(account, passphrase: ethPrivKey)
            let chainId = E.isTestnet ? GethBigInt(3) : GethBigInt(1)
            let signedTx = try! ks?.signTx(account, tx: tx, chainID: chainId)
            try? ks?.delete(account, passphrase: ethPrivKey)
            return signedTx!
        }
    }

    func publishTx(_ tx: GethTransaction) -> Error? {
        do {
            try client.sendTransaction(context, tx:tx)
            return nil
        } catch let e {
            return e
        }
    }

    func transfer(amount: GethBigInt, toAddress: String, privKey: String, token: Token, nonce: Int) -> Error? {
        let address = GethAddress(fromHex: token.address)
        let contract = GethBindContract(address, token.abi, client, nil)

        let opts = GethTransactOpts()
        opts?.setGasLimit(210000)
        opts?.setContext(context)
        opts?.setNonce(Int64(nonce))
        opts?.setGasPrice(try! client.suggestGasPrice(context))
        let signer = Signer(ethPrivKey: privKey)
        opts?.setSigner(signer)

        let boolResult = GethNewInterface()
        boolResult?.setBool(false)
        let result = GethNewInterfaces(1)
        try! result?.set(0, object: boolResult)

        let arg0 = GethNewInterface()
        arg0?.setAddress(GethAddress(fromHex: toAddress))
        let arg1 = GethNewInterface()
        arg1?.setBigInt(amount)
        let args = GethNewInterfaces(2)
        try! args?.set(0, object: arg0)
        try! args?.set(1, object: arg1)

        do {
            try contract?.transact(opts, method: "transfer", args: args)
            return nil
        } catch let e {
            return e
        }
    }
}

extension GethManager {

    func getStartTime() -> Date? {
        guard let startTime = callBigInt(method: "startTime")?.getString(10) else { return nil }
        guard let timestamp = TimeInterval(startTime) else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    func getEndTime() -> Date? {
        guard let endTime = callBigInt(method: "endTime")?.getString(10) else { return nil }
        guard let timestamp = TimeInterval(endTime) else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    func callBigInt(method: String) -> GethBigInt? {
        let address = GethAddress(fromHex: "0x4B0B6b8E05dCF1D1bFD3C19e2ea8707b35D03cD7")
        var error: NSError? = nil
        let contract = GethBindContract(address, crowdSaleABI, client, &error)

        let opts = GethNewCallOpts()
        let out = GethNewInterfaces(1)
        let args = GethNewInterfaces(0)

        let result0 = GethNewInterface()
        result0?.setBigInt(GethNewBigInt(0))
        try! out?.set(0, object: result0)

        do {
            try contract?.call(opts, out_: out, method: method, args: args)
            return result0?.getBigInt()
        } catch let e {
            print("e2: \(e)")
            return nil
        }
    }

    func getBalance() {

        let address = GethAddress(fromHex: "0xab6e259770002a88ff37b23755ddd3743e8a98a2")
        var error: NSError? = nil
        let contract = GethBindContract(address, xjp.abi, client, &error)

        if let e = error {
            print("e: \(e)")
            print("")
        }

        let opts = GethNewCallOpts()
        let out = GethNewInterfaces(1)
        let args = GethNewInterfaces(1)

        let arg0 = GethNewInterface()
        arg0?.setAddress(GethAddress(fromHex: "0xbDFdAd139440D2Db9BA2aa3B7081C2dE39291508"))
        try! args?.set(0, object: arg0)

        let result0 = GethNewInterface()
        result0?.setBigInt(GethNewBigInt(0))
        try! out?.set(0, object: result0)

        do {
            try contract?.call(opts, out_: out, method: "balanceOf", args: args)

            print("balanceOf: \(result0?.getBigInt().getString(10))")
        } catch let e {
            print("e2: \(e)")
        }
    }
}

class Signer : NSObject, GethSignerProtocol {

    init(ethPrivKey: String) {
        self.ethPrivKey = ethPrivKey
    }
    let ethPrivKey: String

    func sign(_ p0: GethAddress!, p1: GethTransaction!) throws -> GethTransaction {
        let ks = GethKeyStore(NSTemporaryDirectory(), scryptN:2, scryptP:1)
        var data = CFDataCreateMutable(secureAllocator, MemoryLayout<UInt256>.stride) as Data
        data.count = MemoryLayout<UInt256>.stride
        var key = BRKey(privKey: ethPrivKey)
        data.withUnsafeMutableBytes({ $0.pointee = key!.secret })
        key!.clean()
        let account = try! ks?.importECDSAKey(data, passphrase: ethPrivKey)
        try? ks?.unlock(account, passphrase: ethPrivKey)
        let chainId = E.isTestnet ? GethBigInt(3) : GethBigInt(1)
        let signedTx = try! ks?.signTx(account, tx: p1, chainID: chainId)
        try? ks?.delete(account, passphrase: ethPrivKey)
        return signedTx!
    }
}