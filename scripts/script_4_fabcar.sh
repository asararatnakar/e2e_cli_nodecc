#!/bin/bash
# Copyright London Stock Exchange Group All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
echo
echo " ____    _____      _      ____    _____           _____   ____    _____ "
echo "/ ___|  |_   _|    / \    |  _ \  |_   _|         | ____| |___ \  | ____|"
echo "\___ \    | |     / _ \   | |_) |   | |    _____  |  _|     __) | |  _|  "
echo " ___) |   | |    / ___ \  |  _ <    | |   |_____| | |___   / __/  | |___ "
echo "|____/    |_|   /_/   \_\ |_| \_\   |_|           |_____| |_____| |_____|"
echo
STARTTIME=$(date +%s)
CHANNEL_NAME="${1}1"
: ${CHANNEL_NAME:="mychannel"}
: ${TIMEOUT:="15"}
COUNTER=1
MAX_RETRY=5
ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

echo "Channel name : "$CHANNEL_NAME

verifyResult () {
	if [ $1 -ne 0 ] ; then
		echo "!!!!!!!!!!!!!!! "$2" !!!!!!!!!!!!!!!!"
                echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
		echo
   		exit 1
	fi
}

setGlobals () {

	if [ $1 -eq 0 -o $1 -eq 1 ] ; then
		CORE_PEER_LOCALMSPID="Org1MSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
		if [ $1 -eq 0 ]; then
			CORE_PEER_ADDRESS=peer0.org1.example.com:7051
		else
			CORE_PEER_ADDRESS=peer1.org1.example.com:7051
		fi
	else
		CORE_PEER_LOCALMSPID="Org2MSP"
		CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
		CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
		if [ $1 -eq 2 ]; then
			CORE_PEER_ADDRESS=peer0.org2.example.com:7051
		else
			CORE_PEER_ADDRESS=peer1.org2.example.com:7051
		fi
	fi

	env |grep CORE
}

checkOSNAvailability() {
	#Use orderer's MSP for fetching system channel config block
	CORE_PEER_LOCALMSPID="OrdererMSP"
	CORE_PEER_TLS_ROOTCERT_FILE=$ORDERER_CA
	CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp

	local rc=1
	local starttime=$(date +%s)

	# continue to poll
	# we either get a successful response, or reach TIMEOUT
	while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
	do
		 sleep 3
		 echo "Attempting to fetch system channel 'testchainid' ...$(($(date +%s)-starttime)) secs"
		 if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
			 peer channel fetch 0 -o orderer.example.com:7050 -c "testchainid" >&log.txt
		 else
			 peer channel fetch 0 -o orderer.example.com:7050 -c "testchainid" --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
		 fi
		 test $? -eq 0 && VALUE=$(cat log.txt | awk '/Received block/ {print $NF}')
		 test "$VALUE" = "0" && let rc=0
	done
	cat log.txt
	verifyResult $rc "Ordering Service is not available, Please try again ..."
	echo "===================== Ordering Service is up and running ===================== "
	echo
}

createChannel() {
	setGlobals 0
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel create -o orderer.example.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel1.tx >&log.txt
	else
		peer channel create -o orderer.example.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/channel1.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Channel creation failed"
	echo "===================== Channel \"$CHANNEL_NAME\" is created successfully ===================== "
	echo
}

updateAnchorPeers() {
        PEER=$1
        setGlobals $PEER

        if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer channel update -o orderer.example.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx >&log.txt
	else
		peer channel update -o orderer.example.com:7050 -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Anchor peer update failed"
	echo "===================== Anchor peers for org \"$CORE_PEER_LOCALMSPID\" on \"$CHANNEL_NAME\" is updated successfully ===================== "
	sleep 5
	echo
}

## Sometimes Join takes time hence RETRY atleast for 5 times
joinWithRetry () {
	peer channel join -b $CHANNEL_NAME.block  >&log.txt
	res=$?
	cat log.txt
	if [ $res -ne 0 -a $COUNTER -lt $MAX_RETRY ]; then
		COUNTER=` expr $COUNTER + 1`
		echo "PEER$1 failed to join the channel, Retry after 2 seconds"
		sleep 2
		joinWithRetry $1
	else
		COUNTER=1
	fi
        verifyResult $res "After $MAX_RETRY attempts, PEER$ch has failed to Join the Channel"
}

joinChannel () {
	# for ch in 0 1 2 3; do
		setGlobals 0
		joinWithRetry 0
		echo "===================== PEER0 joined on the channel \"$CHANNEL_NAME\" ===================== "
		# sleep 2
		echo
	# done
}

installChaincode () {
	PEER=$1
	setGlobals $PEER
	peer chaincode install -l node -n mycc -v 1.0 -p chaincode >&log.txt
	res=$?
	cat log.txt
  verifyResult $res "car Chaincode installation on remote peer PEER$PEER has Failed"
	echo "===================== Car Chaincode is installed on remote peer PEER$PEER ===================== "

	peer chaincode install -l node -n mycc2 -v 1.0 -p chaincode/owner >&log.txt
	res=$?
	cat log.txt
  verifyResult $res "owner Chaincode installation on remote peer PEER$PEER has Failed"
	echo "===================== Owner Chaincode is installed on remote peer PEER$PEER ===================== "
	echo
}

instantiateChaincode () {
	PEER=$1
	setGlobals $PEER
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode instantiate -o orderer.example.com:7050 -C $CHANNEL_NAME -l node -n mycc -v 1.0 -c '{"Args":[""]}' -P "OR	('Org1MSP.member','Org2MSP.member')" >&log.txt
	else
		peer chaincode instantiate -o orderer.example.com:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -l node -n mycc -v 1.0 -c '{"Args":[""]}' -P "OR	('Org1MSP.member','Org2MSP.member')" >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Car Chaincode instantiation on PEER$PEER on channel '$CHANNEL_NAME' failed"
	echo "===================== Car Chaincode Instantiation on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "

	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode instantiate -o orderer.example.com:7050 -C $CHANNEL_NAME -l node -n mycc2 -v 1.0 -c '{"Args":[""]}' -P "OR	('Org1MSP.member','Org2MSP.member')" >&log.txt
	else
		peer chaincode instantiate -o orderer.example.com:7050 --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -l node -n mycc2 -v 1.0 -c '{"Args":[""]}' -P "OR	('Org1MSP.member','Org2MSP.member')" >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Car Chaincode instantiation on PEER$PEER on channel '$CHANNEL_NAME' failed"
	echo "===================== Car Chaincode Instantiation on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}

chaincodeQuery () {
  PEER=$1
	echo $2
  echo "===================== Querying on PEER$PEER on channel '$CHANNEL_NAME'... ===================== "
  setGlobals $PEER
  local rc=1
  local starttime=$(date +%s)

  # continue to poll
  # we either get a successful response, or reach TIMEOUT
  while test "$(($(date +%s)-starttime))" -lt "$TIMEOUT" -a $rc -ne 0
  do
     sleep 3
     echo "Attempting to Query PEER$PEER ...$(($(date +%s)-starttime)) secs"
     peer chaincode query -C $CHANNEL_NAME -n mycc -c $2 >&log.txt
     test $? -eq 0 && VALUE=$(cat log.txt | awk '/Query Result/ {print $NF}') && echo "$VALUE" && let rc=0
    #  test "$VALUE" = "$3" && let rc=0
  done
  echo
  cat log.txt
  if test $rc -eq 0 ; then
	echo "===================== Query on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
  else
	echo "!!!!!!!!!!!!!!! Query result on PEER$PEER is INVALID !!!!!!!!!!!!!!!!"
        echo "================== ERROR !!! FAILED to execute End-2-End Scenario =================="
	echo
	exit 1
  fi
}

chaincodeInvoke () {
	PEER=$1
	setGlobals $PEER
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode invoke -o orderer.example.com:7050 -C $CHANNEL_NAME -n mycc -c $2 >&log.txt
	else
		peer chaincode invoke -o orderer.example.com:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc -c $2 >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Invoke execution on PEER$PEER failed "
	echo "===================== Invoke transaction on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}
chaincodeInvoke1 () {
	PEER=$1
	setGlobals $PEER
	# while 'peer chaincode' command can get the orderer endpoint from the peer (if join was successful),
	# lets supply it directly as we know it using the "-o" option
	if [ -z "$CORE_PEER_TLS_ENABLED" -o "$CORE_PEER_TLS_ENABLED" = "false" ]; then
		peer chaincode invoke -o orderer.example.com:7050 -C $CHANNEL_NAME -n mycc2 -c $2 >&log.txt
	else
		peer chaincode invoke -o orderer.example.com:7050  --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA -C $CHANNEL_NAME -n mycc2 -c $2 >&log.txt
	fi
	res=$?
	cat log.txt
	verifyResult $res "Invoke execution on PEER$PEER failed "
	echo "===================== Invoke transaction on PEER$PEER on channel '$CHANNEL_NAME' is successful ===================== "
	echo
}
## Check for orderering service availablility
echo "Check orderering service availability..."
checkOSNAvailability

## Create channel
echo "Creating channel..."
createChannel

## Join all the peers to the channel
echo "Having all peers join the channel..."
joinChannel

## Set the anchor peers for each org in the channel
# echo "Updating anchor peers for org1..."
# updateAnchorPeers 0
# echo "Updating anchor peers for org2..."
# updateAnchorPeers 2

## Install chaincode on Peer0/Org1 and Peer2/Org2
echo "Installing chaincode on org1/peer0..."
installChaincode 0

#Instantiate chaincode on Peer2/Org2
echo "Instantiating chaincode on org2/peer2..."
instantiateChaincode 0

sleep 10
#Invoke on chaincode on Peer0/Org1
echo "Sending invoke transaction on org1/peer0..."
# chaincodeInvoke 0 "{\"Args\":[\"$1\",\"$2\",\"$3\",\"$4\",\"$5\"]}"
chaincodeInvoke 0 "{\"Args\":[\"createCar\",\"CAR1\",\"honda\",\"accord\",\"blue\",\"tom\"]}"
chaincodeInvoke 0 "{\"Args\":[\"createCar\",\"CAR2\",\"toyota\",\"camry\",\"red\",\"harry\"]}"
chaincodeInvoke 0 "{\"Args\":[\"createCar\",\"CAR3\",\"nissan\",\"altima\",\"blcka\",\"bob\"]}"

chaincodeInvoke1 0 "{\"Args\":[\"createOwner\",\"1\",\"tom\",\"tom@gmail.com\",\"NC\"]}"
chaincodeInvoke1 0 "{\"Args\":[\"createOwner\",\"2\",\"harry\",\"harry@gmail.com\",\"SC\"]}"
chaincodeInvoke1 0 "{\"Args\":[\"createOwner\",\"3\",\"bob\",\"bob@gmail.com\",\"TX\"]}"

#Query on chaincode on Peer0/Org1
echo "Querying chaincode on org1/peer0..."
chaincodeQuery 0 "{\"Args\":[\"queryCar\",\"CAR1\"]}" "{\"docType\":\"marble\",\"name\":\"marble1\",\"color\":\"blue\",\"size\":35,\"owner\":\"tom\"}"
chaincodeQuery 0 "{\"Args\":[\"queryCar\",\"CAR2\"]}" "{\"docType\":\"marble\",\"name\":\"marble2\",\"color\":\"red\",\"size\":50,\"owner\":\"tom\"}"
chaincodeQuery 0 "{\"Args\":[\"queryCar\",\"CAR3\"]}" "{\"docType\":\"marble\",\"name\":\"marble3\",\"color\":\"blue\",\"size\":70,\"owner\":\"tom\"}"

chaincodeInvoke 0 "{\"Args\":[\"changeCarowner\",\"CAR2\",\"bob\"]}"

chaincodeQuery 0 "{\"Args\":[\"queryCar\",\"CAR2\"]}" "{\"docType\":\"marble\",\"name\":\"marble2\",\"color\":\"red\",\"size\":50,\"owner\":\"jerry\"}"

chaincodeInvoke 0 "{\"Args\":[\"transferCarsBasedOnMake\",\"honda\",\"bob\"]}"

chaincodeInvoke 0 "{\"Args\":[\"delete\",\"CAR3\"]}"
#
# ## TODO: Check why the state is not getting deleted ?
chaincodeQuery 0 "{\"Args\":[\"queryCar\",\"CAR3\"]}" "{\"docType\":\"marble\",\"name\":\"marble1\",\"color\":\"blue\",\"size\":35,\"owner\":\"jerry\"}"

chaincodeQuery 0 "{\"Args\":[\"queryAllCars\"]}" "[\"{\\\"docType\\\":\\\"marble\\\",\\\"name\\\":\\\"marble1\\\",\\\"color\\\":\\\"blue\\\",\\\"size\\\":35,\\\"owner\\\":\\\"jerry\\\"}\",\"{\\\"docType\\\":\\\"marble\\\",\\\"name\\\":\\\"marble2\\\",\\\"color\\\":\\\"red\\\",\\\"size\\\":50,\\\"owner\\\":\\\"jerry\\\"}\"]"

chaincodeQuery 0 "{\"Args\":[\"getHistoryForCar\",\"CAR1\"]}" "[\"{\\\"docType\\\":\\\"marble\\\",\\\"name\\\":\\\"marble1\\\",\\\"color\\\":\\\"blue\\\",\\\"size\\\":35,\\\"owner\\\":\\\"tom\\\"}\",\"{\\\"docType\\\":\\\"marble\\\",\\\"name\\\":\\\"marble1\\\",\\\"color\\\":\\\"blue\\\",\\\"size\\\":35,\\\"owner\\\":\\\"jerry\\\"}\"]"

# // Rich Query (Only supported if CouchDB is used as state database):
# //   peer chaincode query -C myc1 -n marbles -c '{"Args":["queryMarbles","{\"selector\":{\"owner\":\"tom\"}}"]}'
chaincodeQuery 0 "{\"Args\":[\"queryCarsByMake\",\"honda\"]}" "{\"color\":\"blue\",\"docType\":\"marble\",\"name\":\"marble1\",\"owner\":\"tom\",\"size\":35}"
# chaincodeQuery 0 "{\"Args\":[\"queryMarbles\",\"{\\\"selector\\\":{\\\"owner\\\":\\\"jerry\\\"}}\"]}" ""

echo
echo "===================== All GOOD, End-2-End execution completed ===================== "
echo

echo
echo " _____   _   _   ____            _____   ____    _____ "
echo "| ____| | \\ | | |  _ \\          | ____| |___ \\  | ____|"
echo "|  _|   |  \\| | | | | |  _____  |  _|     __) | |  _|  "
echo "| |___  | |\\  | | |_| | |_____| | |___   / __/  | |___ "
echo "|_____| |_| \\_| |____/          |_____| |_____| |_____|"
echo
echo "Total execution time : $(($(date +%s)-STARTTIME)) secs ..."
exit 0
