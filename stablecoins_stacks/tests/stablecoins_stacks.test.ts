import { describe, it, expect, beforeEach } from 'vitest'

type Principal = string

type AllowanceKey = `${Principal}:${Principal}`

interface ContractState {
  tokenName: string
  tokenSymbol: string
  tokenDecimals: number
  tokenSupply: number
  contractOwner: Principal
  isPaused: boolean
  tokenUri?: string
  balances: Record<Principal, number>
  allowances: Record<AllowanceKey, number>
  blacklisted: Set<Principal>
}

let state: ContractState
const principal1 = 'wallet_1'
const principal2 = 'wallet_2'
const principal3 = 'wallet_3'

beforeEach(() => {
  state = {
    tokenName: 'USDStable',
    tokenSymbol: 'USDS',
    tokenDecimals: 6,
    tokenSupply: 0,
    contractOwner: principal1,
    isPaused: false,
    tokenUri: undefined,
    balances: {},
    allowances: {},
    blacklisted: new Set()
  }
})

function getBalance(user: Principal) {
  return state.balances[user] ?? 0
}

function setBalance(user: Principal, amount: number) {
  state.balances[user] = amount
}

function isAuthorized(sender: Principal) {
  return sender === state.contractOwner
}

function isBlacklisted(address: Principal) {
  return state.blacklisted.has(address)
}

function transfer(sender: Principal, recipient: Principal, amount: number): boolean | string {
  if (state.isPaused) return 'ERR-CONTRACT-PAUSED'
  if (isBlacklisted(sender) || isBlacklisted(recipient)) return 'ERR-ADDRESS-BLACKLISTED'
  if (getBalance(sender) < amount) return 'ERR-INSUFFICIENT-BALANCE'
  setBalance(sender, getBalance(sender) - amount)
  setBalance(recipient, getBalance(recipient) + amount)
  return true
}

function mint(sender: Principal, recipient: Principal, amount: number): boolean | string {
  if (!isAuthorized(sender)) return 'ERR-NOT-AUTHORIZED'
  if (state.isPaused) return 'ERR-CONTRACT-PAUSED'
  if (isBlacklisted(recipient)) return 'ERR-ADDRESS-BLACKLISTED'
  if (amount <= 0) return 'ERR-INVALID-AMOUNT'
  setBalance(recipient, getBalance(recipient) + amount)
  state.tokenSupply += amount
  return true
}

function approve(sender: Principal, spender: Principal, amount: number): boolean | string {
  if (state.isPaused) return 'ERR-CONTRACT-PAUSED'
  if (isBlacklisted(sender) || isBlacklisted(spender)) return 'ERR-ADDRESS-BLACKLISTED'
  state.allowances[`${sender}:${spender}`] = amount
  return true
}

function transferFrom(spender: Principal, from: Principal, to: Principal, amount: number): boolean | string {
  const key: AllowanceKey = `${from}:${spender}`
  const allowance = state.allowances[key] ?? 0
  if (state.isPaused) return 'ERR-CONTRACT-PAUSED'
  if (isBlacklisted(spender) || isBlacklisted(from) || isBlacklisted(to)) return 'ERR-ADDRESS-BLACKLISTED'
  if (getBalance(from) < amount) return 'ERR-INSUFFICIENT-BALANCE'
  if (allowance < amount) return 'ERR-INSUFFICIENT-ALLOWANCE'
  setBalance(from, getBalance(from) - amount)
  setBalance(to, getBalance(to) + amount)
  state.allowances[key] = allowance - amount
  return true
}

describe('USDStable Token Contract (mocked logic)', () => {
  it('should return correct initial name/symbol/decimals', () => {
    expect(state.tokenName).toBe('USDStable')
    expect(state.tokenSymbol).toBe('USDS')
    expect(state.tokenDecimals).toBe(6)
  })

  it('should allow contract owner to mint tokens', () => {
    const result = mint(principal1, principal2, 1000)
    expect(result).toBe(true)
    expect(getBalance(principal2)).toBe(1000)
    expect(state.tokenSupply).toBe(1000)
  })

  it('should reject minting by non-owner', () => {
    const result = mint(principal2, principal2, 1000)
    expect(result).toBe('ERR-NOT-AUTHORIZED')
  })

  it('should transfer tokens between users', () => {
    mint(principal1, principal1, 500)
    const result = transfer(principal1, principal2, 300)
    expect(result).toBe(true)
    expect(getBalance(principal1)).toBe(200)
    expect(getBalance(principal2)).toBe(300)
  })

  it('should reject transfer if contract is paused', () => {
    mint(principal1, principal1, 100)
    state.isPaused = true
    const result = transfer(principal1, principal2, 50)
    expect(result).toBe('ERR-CONTRACT-PAUSED')
  })

  it('should reject transfers from blacklisted addresses', () => {
    mint(principal1, principal2, 100)
    state.blacklisted.add(principal2)
    const result = transfer(principal2, principal1, 10)
    expect(result).toBe('ERR-ADDRESS-BLACKLISTED')
  })

  it('should allow approvals and transferFrom', () => {
    mint(principal1, principal2, 200)
    const approveResult = approve(principal2, principal3, 100)
    expect(approveResult).toBe(true)
    const transferFromResult = transferFrom(principal3, principal2, principal1, 50)
    expect(transferFromResult).toBe(true)
    expect(getBalance(principal1)).toBe(50)
    expect(getBalance(principal2)).toBe(150)
  })

  it('should reject transferFrom over allowance', () => {
    mint(principal1, principal2, 200)
    approve(principal2, principal3, 50)
    const result = transferFrom(principal3, principal2, principal1, 100)
    expect(result).toBe('ERR-INSUFFICIENT-ALLOWANCE')
  })
})
