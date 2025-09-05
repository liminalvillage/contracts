import { FundsForwarded, ChildHolonCreated } from "../generated/templates/Splitter/Splitter"
import { FundsForwarded as FundsForwardedEntity, Splitter } from "../generated/schema"
import { BigInt } from "@graphprotocol/graph-ts"

export function handleFundsForwarded(event: FundsForwarded): void {
  let id = event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  let forward = new FundsForwardedEntity(id)
  
  forward.splitterAddress = event.address
  // Try accessing by index instead of property names
  forward.fromAddress = event.parameters[0].value.toAddress()
  forward.toAddress = event.parameters[1].value.toAddress()  
  forward.amount = event.parameters[2].value.toBigInt()
  forward.timestamp = event.block.timestamp
  forward.blockNumber = event.block.number
  forward.txHash = event.transaction.hash
  
  forward.save()
}
export function handleChildHolonCreated(event: ChildHolonCreated): void {
  let splitter = Splitter.load(event.address.toHexString())
  if (splitter != null) {
    if (event.params.childType.toString() == "MANAGED") {
      splitter.managedHolon = event.params.childAddress.toHexString()
    } else if (event.params.childType.toString() == "ZONED") {
      splitter.zonedHolon = event.params.childAddress.toHexString()
    }
    splitter.save()
  }
}