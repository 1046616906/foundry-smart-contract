-include .env

-PHONY: deploy file

build :; forge build

test :; forge test

install :; forge install Cyfrin/foundry-devops smartcontractkit/chainlink-brownie-contracts@1.1.1 transmissions11/solmate

