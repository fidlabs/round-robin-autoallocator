.PHONY: test deploy new mainnet_deploy mainnet_verify prep abi solhint 

include .env

prep:
	forge fmt
	forge test
	solhint 'src/**/*.sol' 'test/**/*.sol' 'script/**/*.sol'
	slither .

abi:
	jq -s '[ .[].abi[] ]' out/*Facet.sol/*.json > RoundRobinAllocator.json

test:
	forge test -vvv

solhint:
	solhint 'src/**/*.sol' 'test/**/*.sol' 'script/**/*.sol'

devnet_deploy:
	forge clean && forge build
	forge script script/DevnetDeploy.s.sol --gas-estimate-multiplier 100000 --disable-block-gas-limit -vvvv --broadcast --rpc-url $(RPC_TEST) --private-key $(PRIVATE_KEY_TEST) 

calibnet_deploy:
	rm -rf cache/ out/
	forge clean && forge build
	forge script script/CalibnetDeploy.s.sol --gas-estimate-multiplier 100000 --disable-block-gas-limit -vvvv --broadcast --rpc-url $(RPC_CALIBNET) --private-key $(PRIVATE_KEY_TEST) 
	./contracts_verify.sh Calibnet

mainnet_deploy:
	rm -rf cache/ out/
	forge clean && forge build
	forge script script/MainnetDeploy.s.sol --gas-estimate-multiplier 100000 --disable-block-gas-limit -vvvv --broadcast --rpc-url $(RPC_MAINNET) --private-key $(PRIVATE_KEY_MAINNET) 
	./contracts_verify.sh Mainnet

mainnet_verify:
	./contracts_verify.sh Mainnet

devnet_upgrade:
	forge clean && forge build
	forge script script/DevnetUpgrade.s.sol --gas-estimate-multiplier 100000 --disable-block-gas-limit -vvvv --broadcast --rpc-url $(RPC_TEST) --private-key $(PRIVATE_KEY_TEST) 

devnet_allocate:
	RUST_LOG=trace cast send --json --value 0.1ether --gas-limit 9000000000 --private-key $(PRIVATE_KEY_TEST) --rpc-url $(RPC_TEST) $(PROXY_ADDRESS_TEST) 'allocate(uint256,(bytes,uint64)[])' 1 '[(0x0181e203922020ab68b07850bae544b4e720ff59fdc7de709a8b5a8e83d6b7ab3ac2fa83e8461b, 2048)]' 

devnet_claim:
	RUST_LOG=trace cast send --json --gas-limit 9000000000 --private-key $(PRIVATE_KEY_TEST) --rpc-url $(RPC_TEST) $(PROXY_ADDRESS_TEST) 'claim(uint256)' 2

devnet_addsp:
	RUST_LOG=trace cast send --json --gas-limit 9000000000 --timeout 500 --private-key $(PRIVATE_KEY_TEST) --rpc-url $(RPC_TEST) $(PROXY_ADDRESS_TEST) "createStorageEntity(address,uint64[])" $(MY_ETH_WALLET) "[1000]"

devnet_getclaims:
	RUST_LOG=trace cast call --json --rpc-url $(RPC_TEST) $(PROXY_ADDRESS_TEST) "getClientPackagesWithClaimStatus(address,bool)" $(MY_ETH_WALLET) true

devnet_fundme:
	docker exec -ti lotus lotus send $(MY_FIL_WALLET) 10000

devnet_getaddr:
	cast wallet address --private-key $(PRIVATE_KEY_TEST) 

devnet_listalloc:
	docker exec -it lotus lotus filplus list-allocations

devnet_topup:
	docker exec -it lotus lotus send t410f5mdib2h66gpvwzequcb5lnm7n4cjgc23fnyvxhi 1000

devnet_filaddress:
	docker exec -it lotus lotus evm stat 0x0CECf804dF05442dC9f40EA5d3d9365c91f184A4

devnet_mineraddress:
	docker exec -it lotus-miner lotus-miner actor control list   

gencov:
	forge coverage --report lcov
	genhtml lcov.info -o report --branch-coverage --ignore-errors inconsistent --ignore-errors corrupt

getsig:
	cast sig "InvalidZeroAddress()"
