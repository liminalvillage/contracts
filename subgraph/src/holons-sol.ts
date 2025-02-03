
import {
  NewFlavor as NewFlavorEvent,
  NewHolon as NewHolonEvent
} from "../generated/Holons.sol/Holons_sol"
import { NewFlavor, NewHolon , HolonContract} from "../generated/schema"
import { Holon } from "../generated/templates"

export function handleNewFlavor(event: NewFlavorEvent): void {
  let entity = new NewFlavor(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.flavor = event.params.flavor
  entity.name = event.params.name

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleNewHolon(event: NewHolonEvent): void {
  let entity = new NewHolon(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )

  const flavorAddress = event.transaction.to
  if (!flavorAddress) {
    throw new Error("Transaction to address is null")
  }
  entity.name = event.params.name
  entity.addr = event.params.addr
  entity.flavor = flavorAddress.toHexString()
  entity.creator = event.transaction.from

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  // Create or update HolonContract entity
  let holonContract = new HolonContract(event.params.addr)
  holonContract.name = event.params.name
  holonContract.creator = event.transaction.from
  holonContract.createdAt = event.block.timestamp

  Holon.create(event.params.addr)

  entity.save()
  holonContract.save()
}
