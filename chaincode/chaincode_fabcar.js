/*
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
*/

'use strict';
const shim = require('fabric-shim');
const util = require('util');
const INDEX = 'make~owner';
let Chaincode = class {

  // The Init method is called when the Smart Contract 'fabcar' is instantiated by the blockchain network
  // Best practice is to have any Ledger initialization in separate function -- see initLedger()
  async Init(stub) {
    console.info('=========== Instantiated fabcar Chaincode ===========');
    return shim.success();
  }

  // The Invoke method is called as a result of an application request to run the Smart Contract
  // 'fabcar'. The calling application program has also specified the particular smart contract
  // function to be called, with arguments
  async Invoke(stub) {
    console.info('Transaction ID: ' + stub.getTxID());
    console.info(util.format('Args: %j', stub.getArgs()));

    let ret = stub.getFunctionAndParameters();
    //TODO: getStringArgs , getArgs
    console.info(ret);

    let method = this[ret.fcn];
    if (!method) {
      console.log('no function of name:' + ret.fcn + ' found');
      throw new Error('Received unknown function ' + ret.fcn + ' invocation');
    }
    try {
      let payload = await method(stub, ret.params, this);
      return shim.success(payload);
    } catch (err) {
      console.log(err);
      return shim.error(err);
    }
  }

  async queryCar(stub, args) {
    if (args.length != 1) {
      throw new Error('Incorrect number of arguments. Expecting CarNumber ex: CAR01');
    }
    let carNumber = args[0];

    let carAsBytes = await stub.getState(carNumber); //get the car from chaincode state
    if (!carAsBytes || carAsBytes.toString().length <= 0) {
      throw new Error(carNumber + ' does not exist: ');
    }
    console.log(carAsBytes.toString());
    return carAsBytes;
  }

  async queryCarOwnerDetails(stub, args) {
    if (args.length != 3) {
      throw new Error('Incorrect number of arguments. Expecting 3');
    }
    let carNumber = args[0];
    let chaincodeName = args[1];
    let channelID = args[2];
    let carAsBytes = await stub.getState(args[0]);
    let car = JSON.parse(carAsBytes);
    // Change this API, if method is changed in other chaincode
    let response = await stub.invokeChaincode(chaincodeName, ['getOwnerDetails', car.owner], channelID)
    if (response.status != stub.RESPONSE_CODE.OK) {
      throw new Error(util.format("Failed to invoke chaincode. Got error: %s", response.payload.toString()));
    }
    return response;
  }

  async initLedger(stub, args) {
    console.info('============= START : Initialize Ledger ===========');
    let cars = [];
    cars.push({
      make: 'Toyota',
      model: 'Prius',
      color: 'blue',
      owner: 'Tomoko'
    });
    cars.push({
      make: 'Ford',
      model: 'Mustang',
      color: 'red',
      owner: 'Brad'
    });
    cars.push({
      make: 'Hyundai',
      model: 'Tucson',
      color: 'green',
      owner: 'Jin Soo'
    });
    cars.push({
      make: 'Volkswagen',
      model: 'Passat',
      color: 'yellow',
      owner: 'Max'
    });
    cars.push({
      make: 'Tesla',
      model: 'S',
      color: 'black',
      owner: 'Adriana'
    });
    cars.push({
      make: 'Peugeot',
      model: '205',
      color: 'purple',
      owner: 'Michel'
    });
    cars.push({
      make: 'Chery',
      model: 'S22L',
      color: 'white',
      owner: 'Aarav'
    });
    cars.push({
      make: 'Fiat',
      model: 'Punto',
      color: 'violet',
      owner: 'Pari'
    });
    cars.push({
      make: 'Tata',
      model: 'Nano',
      color: 'indigo',
      owner: 'Valeria'
    });
    cars.push({
      make: 'Holden',
      model: 'Barina',
      color: 'brown',
      owner: 'Shotaro'
    });

    for (let i = 0; i < cars.length; i++) {
      cars[i].docType = 'car';
      await stub.putState('CAR' + i, Buffer.from(JSON.stringify(cars[i])));
      console.info('Added <--> ', cars[i]);

      let colorNameIndexKey = await stub.createCompositeKey(INDEX, [cars[i].make, cars[i].owner]);
      console.info(colorNameIndexKey);
      //  Save index entry to state. Only the key name is needed, no need to store a duplicate copy of the car.
      //  Note - passing a 'nil' value will effectively delete the key from state, therefore we pass null character as value
      await stub.putState(colorNameIndexKey, Buffer.from('\u0000'));
    }
    console.info('============= END : Initialize Ledger ===========');
  }

  async createCar(stub, args) {
    console.info('============= START : Create Car ===========');
    if (args.length != 5) {
      throw new Error('Incorrect number of arguments. Expecting 5');
    }

    var car = {
      docType: 'car',
      make: args[1],
      model: args[2],
      color: args[3],
      owner: args[4]
    };

    await stub.putState(args[0], Buffer.from(JSON.stringify(car)));
    console.info('============= END : Create Car ===========');
  }

  // ==================================================
  // delete - remove a car key/value pair from state
  // ==================================================
  async delete(stub, args, thisClass) {
    if (args.length != 1) {
      throw new Error('Incorrect number of arguments. Expecting name of the car to delete');
    }
    let carNumber = args[0];
    if (!carNumber) {
      throw new Error('car number must not be empty');
    }
    // to maintain the color~name index, we need to read the car first and get its color
    let valAsbytes = await stub.getState(carNumber); //get the car from chaincode state
    if (!valAsbytes || valAsbytes.toString() === '') {
      throw new Error(carNumber + ' does not exist');
    }
    let carAsJSON = {};
    try {
      carAsJSON = JSON.parse(valAsbytes.toString());
    } catch (err) {
      throw new Error('Failed to decode JSON of car ' + carNumber);
    }

    await stub.deleteState(carNumber); //remove the car from chaincode state

    // delete the index
    let colorNameIndexKey = stub.createCompositeKey(INDEX, [carAsJSON.make, carAsJSON.owner]);
    if (!colorNameIndexKey) {
      throw new Error(' Failed to create the createCompositeKey');
    }
    //  Delete index entry to state.
    await stub.deleteState(colorNameIndexKey);
  }

  async queryAllCars(stub, args, thisClass) {

    let startKey = 'CAR0';
    let endKey = 'CAR999';

    let iterator = await stub.getStateByRange(startKey, endKey);

    let allResults = [];
    while (true) {
      let res = await iterator.next();

      if (res.value && res.value.value.toString()) {
        let jsonRes = {};
        console.log(res.value.value.toString('utf8'));

        jsonRes.Key = res.value.key;
        try {
          jsonRes.Record = JSON.parse(res.value.value.toString('utf8'));
        } catch (err) {
          console.log(err);
          jsonRes.Record = res.value.value.toString('utf8');
        }
        allResults.push(jsonRes);
      }
      if (res.done) {
        console.log('end of data');
        await iterator.close();
        console.info(allResults);
        return Buffer.from(JSON.stringify(allResults));
      }
    }
  }

  async changeCarowner(stub, args, thisClass) {
    console.info('============= START : changeCarowner ===========');
    if (args.length != 2) {
      throw new Error('Incorrect number of arguments. Expecting 2');
    }

    let carAsBytes = await stub.getState(args[0]);
    let car = JSON.parse(carAsBytes);
    car.owner = args[1];

    await stub.putState(args[0], Buffer.from(JSON.stringify(car)));
  }

  async transferCarsBasedOnMake(stub, args, thisClass) {

    //   0       1
    // 'color', 'bob'
    if (args.length < 2) {
      throw new Error('Incorrect number of arguments. Expecting model and owner');
    }

    let make = args[0];
    let newOwner = args[1].toLowerCase();
    console.info('- start transferCarsBasedOnMake ', make, newOwner);

    // Query the color~name index by color
    // This will execute a key range query on all keys starting with 'color'
    let carModelsIterator = await stub.getStateByPartialCompositeKey(INDEX, [make]);

    let method = thisClass['changeCarowner'];
    // Iterate through result set and for each car found, transfer to newOwner
    while (true) {
      let responseRange = await carModelsIterator.next();
      if (!responseRange || !responseRange.value || !responseRange.value.key) {
        return;
      }
      console.log(responseRange.value.key);

      // let value = res.value.value.toString('utf8');
      let objectType;
      let attributes;
      ({
        objectType,
        attributes
      } = await stub.splitCompositeKey(responseRange.value.key));

      make = attributes[0];
      let owner = attributes[1];
      console.info(util.format('- found a car from index:%s make:%s owner:%s\n', objectType, make, owner));

      // Now call the transfer function for the found car.
      // Re-use the same function that is used to transfer individual car
      let response = await method(stub, [owner, newOwner]);
    }

    let responsePayload = util.format('Transferred %s car to %s', owner, newOwner);
    console.info('- end transferCarsBasedOnMake: ' + responsePayload);
  }

  async queryCarsByMake(stub, args, thisClass) {
    //   0
    // 'Chevy'
    if (args.length < 1) {
      throw new Error('Incorrect number of arguments. Expecting car make.')
    }

    let make = args[0].toLowerCase();
    let queryString = {};
    queryString.selector = {};
    queryString.selector.docType = 'car';
    queryString.selector.make = make;
    let method = thisClass['getRichQueryResult'];
    let queryResults = await method(stub, JSON.stringify(queryString), thisClass);
    return queryResults; //shim.success(queryResults);
  }

  async getAllResults(iterator) {
    let allResults = [];
    while (true) {
      let res = await iterator.next();
      // console.log(res);
      if (res.value && res.value.value.toString()) {
        let value = res.value.value.toString('utf8');
        allResults.push(value);
        console.log(value);
      }
      if (res.done) {
        console.log('end of data');
        await iterator.close();
        return allResults;
      }
    }
  }

  async getRichQueryResult(stub, queryString, thisClass) {

    console.info('- getRichQueryResult with queryString:\n' + queryString)
    let resultsIterator = await stub.getQueryResult(queryString);
    console.log(resultsIterator);
    let method = thisClass['getAllResults'];

    let results = await method(resultsIterator);

    return Buffer.from(JSON.stringify(results));
  }

  async getHistoryForCar(stub, args, thisClass) {
    if (args.length < 1) {
      throw new Error('Incorrect number of arguments. Expecting carNumber')
    }
    let carNumber = args[0];
    console.info('- start getHistoryForCar: %s\n', carNumber);

    let resultsIterator = await stub.getHistoryForKey(carNumber);
    let method = thisClass['getAllResults'];
    let results = await method(resultsIterator);

    return Buffer.from(JSON.stringify(results));
  }

  getTxID(stub, args) {
    let transactionID = stub.getTxID();
    console.info('-------- Transaction ID : ', transactionID);
    return Buffer.from(transactionID.toString());
  }

  getTransient(stub, args) {
    let transient = stub.getTransient();
    console.info('-------- transient : ', transient);
    return Buffer.from(transient.toString());
  }

  getCreator(stub, args) {
    let creator = stub.getCreator();
    console.info('-------- Creator Identity : ', creator.toString());
    return Buffer.from(creator.toString());
  }

  getSignedProposal(stub, args) {
    let proposal = stub.getSignedProposal();
    console.log(proposal);
    return Buffer.from(proposal.toString());
  }

  getTxTimestamp(stub, args) {
    let txTimestamp = stub.getTxTimestamp();
    console.log(txTimestamp);
    return Buffer.from(txTimestamp.toString());
  }

  getBinding(stub, args) {
    let binding = stub.getBinding();
    console.log(binding);
    return Buffer.from(binding.toString());
  }
};

shim.start(new Chaincode());
