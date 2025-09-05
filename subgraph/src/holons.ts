import { NewHolon } from "../generated/Holons.sol/Holons_sol"
import { Holon, Splitter, HolonsContract } from "../generated/schema"
import { Splitter as SplitterTemplate } from "../generated/templates"


import { BigInt, Address } from "@graphprotocol/graph-ts"

export function handleNewHolon(event: NewHolon): void {
  // Create Holon entity
  let holon = new Holon(event.params.name)
  holon.name = event.params.name
  holon.address = event.params.addr
  holon.creatorUserId = "unknown" // Default value since not available in NewHolon event
  holon.holonType = "SPLITTER"
  holon.parameter = null // Not applicable for Splitter holons
  holon.createdAt = event.block.timestamp
  holon.blockNumber = event.block.number
  holon.txHash = event.transaction.hash
  
  // Create Splitter entity
  let splitter = new Splitter(event.params.addr.toHexString())
  splitter.name = event.params.name
  splitter.address = event.params.addr
  splitter.creatorUserId = "unknown" // Default value since not available in NewHolon event
  splitter.parameter = BigInt.fromI32(0) // Default value since not available in NewHolon event
  splitter.createdAt = event.block.timestamp
  splitter.blockNumber = event.block.number
  splitter.txHash = event.transaction.hash
  
  // Link holon to splitter
  holon.splitter = splitter.id
  
  // Start indexing the new Splitter contract
  SplitterTemplate.create(event.params.addr)
  
  // Update factory stats
  let factory = HolonsContract.load(event.address.toHexString())
  if (factory == null) {
    factory = new HolonsContract(event.address.toHexString())
    factory.totalHolons = BigInt.fromI32(0)
    factory.totalSplitters = BigInt.fromI32(0)
    factory.createdAt = event.block.timestamp
  }
  factory.totalHolons = factory.totalHolons.plus(BigInt.fromI32(1))
  factory.totalSplitters = factory.totalSplitters.plus(BigInt.fromI32(1))
  
  splitter.save()
  holon.save()
  factory.save()
}