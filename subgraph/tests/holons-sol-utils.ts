import { newMockEvent } from "matchstick-as"
import { ethereum, Address } from "@graphprotocol/graph-ts"
import { NewFlavor, NewHolon } from "../generated/Holons.sol/Holons.sol"

export function createNewFlavorEvent(flavor: Address, name: string): NewFlavor {
  let newFlavorEvent = changetype<NewFlavor>(newMockEvent())

  newFlavorEvent.parameters = new Array()

  newFlavorEvent.parameters.push(
    new ethereum.EventParam("flavor", ethereum.Value.fromAddress(flavor))
  )
  newFlavorEvent.parameters.push(
    new ethereum.EventParam("name", ethereum.Value.fromString(name))
  )

  return newFlavorEvent
}

export function createNewHolonEvent(name: string, addr: Address): NewHolon {
  let newHolonEvent = changetype<NewHolon>(newMockEvent())

  newHolonEvent.parameters = new Array()

  newHolonEvent.parameters.push(
    new ethereum.EventParam("name", ethereum.Value.fromString(name))
  )
  newHolonEvent.parameters.push(
    new ethereum.EventParam("addr", ethereum.Value.fromAddress(addr))
  )

  return newHolonEvent
}
