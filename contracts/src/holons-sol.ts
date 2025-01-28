import {
  NewFlavor as NewFlavorEvent,
  NewHolon as NewHolonEvent
} from "../generated/Holons.sol/Holons.sol"
import { NewFlavor, NewHolon } from "../generated/schema"

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
  entity.name = event.params.name
  entity.addr = event.params.addr

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
