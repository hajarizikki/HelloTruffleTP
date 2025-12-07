import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web_socket_channel/io.dart';

class ContractLinking extends ChangeNotifier {
  // URL RPC : différent entre Web et Android
  final String _rpcUrl =
      kIsWeb ? "http://127.0.0.1:7545" : "http://10.0.2.2:7545";
  final String _wsUrl =
      kIsWeb ? "ws://127.0.0.1:7545/" : "ws://10.0.2.2:7545/";

  // Clé privée Ganache
  final String _privateKey =
      "0x3b9aff31c98fa9997810904205005214b6ca22c5d68089460ddfbca83e5d5f34";

  late Web3Client _client;
  bool isLoading = true;
  late String _abiCode;
  late EthereumAddress _contractAddress;
  late Credentials _credentials;
  late DeployedContract _contract;
  late ContractFunction _yourName;
  late ContractFunction _setName;
  late String deployedName = "Unknown";

  ContractLinking() {
    initialSetup();
  }

  Future<void> initialSetup() async {
    // Sur le web : pas de WebSocket, juste HTTP
    if (kIsWeb) {
      _client = Web3Client(_rpcUrl, Client());
    } else {
      _client = Web3Client(_rpcUrl, Client(), socketConnector: () {
        return IOWebSocketChannel.connect(_wsUrl).cast<String>();
      });
    }

    await getAbi();
    await getCredentials();
    await getDeployedContract();
  }

  Future<void> getAbi() async {
    String abiStringFile =
        await rootBundle.loadString("src/artifacts/HelloWorld.json");
    var jsonAbi = jsonDecode(abiStringFile);
    _abiCode = jsonEncode(jsonAbi["abi"]);

    final netId = jsonAbi["networks"]?["5777"];
    if (netId == null) {
      throw Exception(
          "Le fichier JSON n'a pas d'entrée pour le réseau 5777. Vérifie HelloWorld.json");
    }
    _contractAddress =
        EthereumAddress.fromHex(jsonAbi["networks"]["5777"]["address"]);
  }

  Future<void> getCredentials() async {
    _credentials = EthPrivateKey.fromHex(_privateKey);
  }

  Future<void> getDeployedContract() async {
    _contract = DeployedContract(
      ContractAbi.fromJson(_abiCode, "HelloWorld"),
      _contractAddress,
    );
    _yourName = _contract.function("yourName");
    _setName = _contract.function("setName");
    await getName();
  }

  Future<void> getName() async {
    final currentName =
        await _client.call(contract: _contract, function: _yourName, params: []);
    deployedName =
        (currentName.isNotEmpty) ? currentName[0].toString() : "Unknown";
    isLoading = false;
    notifyListeners();
  }

  Future<void> setName(String nameToSet) async {
    isLoading = true;
    notifyListeners();

    await _client.sendTransaction(
      _credentials,
      Transaction.callContract(
        contract: _contract,
        function: _setName,
        parameters: [nameToSet],
      ),
      // IMPORTANT : on enlève fetchChainIdFromNetworkId et on fixe le chainId Ganache
      chainId: 1337, // si Ganache utilise un autre chainId, tu le changes ici
    );

    await getName();
  }
}
