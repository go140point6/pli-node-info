A1. Oracle Contract

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
import "@goplugin/test/src/v0.7/Operator.sol";
```

When deploying, the "PLI" field needs to be in format

Mainnet:
    
```
"0xff7412ea7c8445c46a8254dfb557ac1e48094391"
```
    
Apothem:
    
```
"0x33f4212b027e22af7e6ba21fc572843c0d701cd1"
```

And "OWNER" field needs to be your XDC address in same format

```
"0x..."
```

After deploying, document the OCA for later use.

A2. Node Fulfillment

In deployed Oracle, pass your Node Address (found under Key Management) to 'setAuthorizedSenders' in format

```
["0x..."]
```

A3. Fund you Node Address by sending 1 PLI and 1 XDC.

B. Bridge Creation

This section is not used for this sample test.

C. Job Submission

Submit a new job using the sample test Job Spec substituting your OCA for what is here in the contractAddress line AND the submit_tx line:

```
type = "directrequest"
schemaVersion = 1
name = "JobNameOfYourChoice"
forwardingAllowed = false
maxTaskDuration = "0s"
contractAddress = "0x1332f3dCdE3c7B4A7119808F651980f3DFB57BF1"
minContractPaymentLinkJuels = "0"
observationSource = """
 
decode_log [type="ethabidecodelog" abi="OracleRequest(bytes32 indexed specId, address requester, bytes32 requestId, uint256 payment, address callbackAddr, bytes4 callbackFunctionId, uint256 cancelExpiration, uint256 dataVersion, bytes data)" data="$(jobRun.logData)" topics="$(jobRun.logTopics)"] 

decode_cbor [type="cborparse" data="$(decode_log.data)"] 

fetch [type=http method=GET url="https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD" allowUnrestrictedNetworkAccess="true"];
parse [type="jsonparse" path="USD" data="$(fetch)"] 

multiply [type="multiply" input="$(parse)" times="$(decode_cbor.times)"] 

encode_data [type="ethabiencode" abi="(bytes32 requestId, uint256 value)" data="{ \\"requestId\\": $(decode_log.requestId), \\"value\\": $(multiply) }"] 

encode_tx [type="ethabiencode" abi="fulfillOracleRequest2(bytes32 requestId, uint256 payment, address callbackAddress, bytes4 callbackFunctionId, uint256 expiration, bytes calldata data)" 
data="{\\"requestId\\": $(decode_log.requestId), \\"payment\\": $(decode_log.payment), \\"callbackAddress\\": $(decode_log.callbackAddr), \\"callbackFunctionId\\": $(decode_log.callbackFunctionId), \\"expiration\\": $(decode_log.cancelExpiration), \\"data\\": $(encode_data)}" ] 

submit_tx [type="ethtx" to="0x1332f3dCdE3c7B4A7119808F651980f3DFB57BF1" data="$(encode_tx)"]

decode_log -> decode_cbor -> fetch -> parse -> multiply -> encode_data -> encode_tx -> submit_tx 
"""
```

Take the Job ID created and remove the hyphens leaving just the numbers:

```
81fbff46e4d14dec9e44cc366661dd1d
```

D. Consumer Contract

A. Pli Token - leave this as-is for Apothem, change for Mainnet
B. Oracle - This is your newly created OCA
C. jobId - This is your newly created jobId (formatted without the hyphens)

Note: Be sure to change where the code is actually used and not just change the comments.

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@goplugin/test/src/v0.8/PluginClient.sol";
import "@goplugin/test/src/v0.8/ConfirmedOwner.sol";
/**
* THIS IS AN EXAMPLE CONTRACT WHICH USES HARDCODED VALUES FOR CLARITY.
* THIS EXAMPLE USES UN-AUDITED CODE.
* DO NOT USE THIS CODE IN PRODUCTION.
*/
contract APIConsumer is PluginClient, ConfirmedOwner {
using Plugin for Plugin.Request;
uint256 public volume;
bytes32 private jobId;
uint256 private fee;
event RequestVolume(bytes32 indexed requestId, uint256 volume);
/**
* @notice Initialize the pli token and target oracle
*
* Details:
* A. Pli Token: 0x33f4212b027E22aF7e6BA21Fc572843C0D701CD1
* B. Oracle: 0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD (Plugin DevRel)
* C. jobId: ca98366cc7314957b8c012c72f05aeeb
*
*/
constructor() ConfirmedOwner(msg.sender) {
setPluginToken(0x33f4212b027E22aF7e6BA21Fc572843C0D701CD1);//Pli address as mentioned in ‘A’
setPluginOracle(0x1332f3dCdE3c7B4A7119808F651980f3DFB57BF1);//Oracle address
jobId = "8d4aa0ad6151457e8275f96918d66b67";//Job ID as stored in ‘C’ JOB SUBMISSION
fee = (0.001 * 1000000000000000000) / 10;
}
/**
* Create a Plugin request to retrieve API response, find the target
* data, then multiply by 1000000000000000000 (to remove decimal places from
data).
*/
function requestVolumeData() public returns (bytes32 requestId) {
Plugin.Request memory req = buildPluginRequest(
jobId,
address(this),
this.fulfill.selector
);
// Set the URL to perform the GET request on
// req.add(
// "get",
// "https://min-api.cryptocompare.com/data/pricemultifull?fsyms=ETH&tsyms=USD"
// );
req.add(
"get",
"https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD"
);
// Set the path to find the desired data in the API response, where the response format is:
// {"RAW":
// {"ETH":
// {"USD":
// {
// "VOLUME24HOUR": xxx.xxx,
// }
// }
// }
// }
// request.add("path", "RAW.ETH.USD.VOLUME24HOUR"); // Plugin nodes prior to 1.0.0 support this format
//req.add("path", "RAW.ETH.USD.VOLUME24HOUR"); // Plugin nodes 1.0.0 and later support this format
//req.add("path", "USD"); // Plugin nodes 1.0.0 and later support this format
//req.add("path", "Result,data,result"); // Plugin nodes 1.0.0 and later support this format
// Multiply the result by 1000000000000000000 to remove decimals 
int256 timesAmount = 10 ** 18;
req.addInt("times", timesAmount);
// Sends the request
return sendPluginRequest(req, fee);
}
/**
* Receive the response in the form of uint256
*/
function fulfill(
bytes32 _requestId,
uint256 _volume
) public recordPluginFulfillment(_requestId) {
emit RequestVolume(_requestId, _volume);
volume = _volume;
}
/**
* Allow withdraw of Link tokens from the contract
*/
function withdrawPli() public onlyOwner {
PliTokenInterface pli = PliTokenInterface(PluginTokenAddress());
require(
pli.transfer(msg.sender, pli.balanceOf(address(this))),
"Unable to transfer"
);
}
}
```

Once deployed, fund the newly created Consumer Contract Address with at least 0.1 PLI.  
Then use the 'requestVolumeData' and after a few seconds, click 'volume' to get the ETH-USD value.  
You should also see the attempt against your node.






