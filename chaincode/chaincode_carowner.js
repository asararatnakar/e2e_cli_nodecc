/*
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
*/

'use strict';
const shim = require('fabric-shim');
const util = require('util');

let Chaincode = class {

  // The Init method is called when the Smart Contract is instantiated on the blockchain network
  async Init(stub) {
    console.info('=========== Instantiated Chaincode ===========');
    return shim.success();
  }

  async Invoke(stub) {
    console.info('Transaction ID: ' + stub.getTxID());
    console.info(util.format('Args: %j', stub.getArgs()));

    let ret = stub.getFunctionAndParameters();
    console.info(ret);

    let method = this[ret.fcn];
    if (!method) {
      console.log('no function of name:' + ret.fcn + ' found');
      throw new Error('Received unknown function ' + ret.fcn + ' invocation');
    }
    try {
      let payload = await method(stub, ret.params);
      return shim.success(payload);
    } catch (err) {
      console.log(err);
      return shim.error(err);
    }
  }

  async getOwnerDetails(stub, args) {
    if (args.length != 1) {
      throw new Error('Incorrect number of arguments. Expecting name ex: tomoko');
    }
    let owner = args[0];

    let detailsAsBytes = await stub.getState(owner.toLowerCase()); //get the car from chaincode state
    if (!detailsAsBytes.toString() ||  detailsAsBytes.toString() === '') {
      throw new Error(owner+' does not exist');
    }
    console.log(detailsAsBytes.toString());
    return detailsAsBytes;
  }

  async initLedger(stub, args) {
    console.info('============= START : Initialize Ledger ===========');
    let carOwner = [];
    carOwner.push({
      id: '1',
      name: 'Tomoko',
      email: 'tomoko@gmail.com',
      state: 'NC'
    });
    carOwner.push({
      id: '2',
      name: 'Brad',
      email: 'brad@gmail.com',
      state: 'SC'
    });
    carOwner.push({
      id: '3',
      name: 'Jin Soo',
      email: 'jin@gmail.com',
      state: 'TX'
    });
    carOwner.push({
      id: '4',
      name: 'Max',
      email: 'max@gmail.com',
      state: 'SF'
    });
    carOwner.push({
      id: '5',
      name: 'Adriana',
      email: 'adriana@gmail.com',
      state: 'NC'
    });
    carOwner.push({
      id: '6',
      name: 'Michel',
      email: 'michel@gmail.com',
      state: 'FL'
    });
    carOwner.push({
      id: '7',
      name: 'Aarav',
      email: 'aarav@gmail.com',
      state: 'NY'
    });
    carOwner.push({
      id: '8',
      name: 'Pari',
      email: 'pari@gmail.com',
      state: 'DC'
    });
    carOwner.push({
      id: '9',
      name: 'Valeria',
      email: 'valeria@gmail.com',
      state: 'MA'
    });
    carOwner.push({
      id: '10',
      name: 'Shotaro',
      email: 'shotaro@gmail.com',
      state: 'SD'
    });

    for (let i = 1; i <= carOwner.length; i++) {
      await stub.putState(carOwner[i].name.toLowerCase(), Buffer.from(JSON.stringify(carOwner[i])));
      console.info('Added <--> ', carOwner[i]);
    }
    console.info('============= END : Initialize Ledger ===========');
  }

  async createOwner(stub, args) {
    console.info('============= START : Create Owner ===========');
    if (args.length != 4) {
      throw new Error('Incorrect number of arguments. Expecting 4');
    }

    var owner = {
      id: args[0],
      name: args[1].toLowerCase(),
      email: args[2],
      state: args[3]
    };

    await stub.putState(owner.name, Buffer.from(JSON.stringify(owner)));
    console.info('============= END : Create Car ===========');
  }
};
shim.start(new Chaincode());
