import { FundsForwarded, ChildHolonCreated } from "../generated/templates/Splitter/Splitter"
import { FundsForwarded as FundsForwardedEntity, Splitter } from "../generated/schema"
import { Address, BigInt, Bytes } from "@graphprotocol/graph-ts"
import { Managed as ManagedTemplate, Zoned as ZonedTemplate } from "../generated/templates"


function isZeroAddress(a: Address): boolean {
  return a.equals(Address.zero())
}

export function handleFundsForwarded(event: FundsForwarded): void {
  const id = event.transaction.hash.toHexString() + "-" + event.logIndex.toString()
  const e = new FundsForwardedEntity(id)

  // Now we can use the proper parameter names since they're indexed
  const to = event.params.to
  const token = event.params.token
  const amount = event.params.amount

  const isNative = token.equals(Address.zero())

  e.splitterAddress = event.address
  e.toAddress = to
  e.tokenAddress = isNative ? Address.zero() : token // store zero for native
  e.amount = amount
  e.txHash = event.transaction.hash
  e.blockNumber = event.block.number
  e.timestamp = event.block.timestamp

  e.save()
}

export function handleChildHolonCreated(event: ChildHolonCreated): void {
  let splitter = Splitter.load(event.address.toHexString())
  if (splitter != null) {
    if (event.params.childType.toString() == "MANAGED") {
      splitter.managedHolon = event.params.childAddress.toHexString()
      
      // THIS IS WHAT'S MISSING - Start indexing the Managed contract
      ManagedTemplate.create(event.params.childAddress)
      
    } else if (event.params.childType.toString() == "ZONED") {
      splitter.zonedHolon = event.params.childAddress.toHexString()
      
      // THIS IS WHAT'S MISSING - Start indexing the Zoned contract
      ZonedTemplate.create(event.params.childAddress)
    }
    splitter.save()
  }
}