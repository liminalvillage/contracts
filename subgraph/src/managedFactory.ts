import { ManagedContractCreated } from "../generated/ManagedFactory/ManagedFactory"
import { Managed, ManagedFactory, Splitter } from "../generated/schema"
import { BigInt } from "@graphprotocol/graph-ts"

export function handleManagedContractCreated(event: ManagedContractCreated): void {
  let managed = new Managed(event.params.contractAddress.toHexString())
  managed.name = event.params.name
  managed.address = event.params.contractAddress
  managed.creatorUserId = event.params.creatorUserId.toString()
  managed.creator = event.transaction.from
  managed.createdAt = event.block.timestamp
  managed.blockNumber = event.block.number
  managed.txHash = event.transaction.hash
  
  // Find the parent splitter that created this managed holon
  // The splitter is the transaction sender (msg.sender)
  let parentSplitter = Splitter.load(event.transaction.from.toHexString())
  if (parentSplitter != null) {
    // Link the managed holon to its parent splitter
    parentSplitter.managedHolon = managed.id
    parentSplitter.save()
    
    // Link the managed holon to its parent splitter
    managed.parentSplitter = parentSplitter.id
  }
  
  // Update factory stats
  let factory = ManagedFactory.load(event.address.toHexString())
  if (factory == null) {
    factory = new ManagedFactory(event.address.toHexString())
    factory.totalManaged = BigInt.fromI32(0)
    factory.createdAt = event.block.timestamp
  }
  factory.totalManaged = factory.totalManaged.plus(BigInt.fromI32(1))
  
  managed.save()
  factory.save()
}