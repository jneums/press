// packages/libs/ic-js/src/api/ledger.api.ts

import { type Identity, HttpAgent, Actor } from '@icp-sdk/core/agent';
import { Principal } from '@icp-sdk/core/principal';
import { getHost } from '../config.js';
import { AccountIdentifier } from '@icp-sdk/canisters/ledger/icp';
import { Ledger } from '@press/declarations';

// ICP Ledger canister ID (mainnet)
const ICP_LEDGER_CANISTER_ID = 'ryjl3-tyaaa-aaaaa-aaaba-cai';

type ICPLedger = Ledger._SERVICE;
type IdentityOrAgent = Identity | any;

// Helper to safely stringify errors that may contain BigInt
function stringifyError(err: any): string {
  try {
    return JSON.stringify(err, (_, value) =>
      typeof value === 'bigint' ? value.toString() : value
    );
  } catch {
    return String(err);
  }
}

// Cache for Plug ledger actor to avoid recreating on every call
let cachedPlugLedgerActor: ICPLedger | null = null;

// Helper to detect Plug agents
function isPlugAgent(identityOrAgent: any): boolean {
  return identityOrAgent && 
         typeof identityOrAgent === 'object' && 
         'agent' in identityOrAgent &&
         'getPrincipal' in identityOrAgent &&
         typeof identityOrAgent.getPrincipal === 'function';
}

async function createLedgerActor(identityOrAgent?: IdentityOrAgent): Promise<ICPLedger> {
  // Check if it's a Plug agent - use window.ic.plug.createActor
  if (isPlugAgent(identityOrAgent) && typeof globalThis !== 'undefined' && (globalThis as any).window?.ic?.plug?.createActor) {
    // Return cached actor if available
    if (cachedPlugLedgerActor !== null) {
      return cachedPlugLedgerActor;
    }
    
    // Check if Plug is still connected before calling createActor (which can trigger popup)
    const isConnected = await (globalThis as any).window.ic.plug.isConnected();
    if (!isConnected) {
      throw new Error('Plug session expired. Please reconnect.');
    }
    
    // Create new actor and cache it
    const newActor = await (globalThis as any).window.ic.plug.createActor({
      canisterId: ICP_LEDGER_CANISTER_ID,
      interfaceFactory: Ledger.idlFactory,
    });
    
    cachedPlugLedgerActor = newActor;
    return newActor;
  }

  // It's a standard Identity - create HttpAgent
  const host = getHost();
  const isLocal = host.includes('localhost') || host.includes('127.0.0.1');

  const agent = HttpAgent.createSync({
    host,
    identity: identityOrAgent,
    shouldFetchRootKey: isLocal,
  });

  return Actor.createActor<ICPLedger>(Ledger.idlFactory, {
    agent,
    canisterId: ICP_LEDGER_CANISTER_ID,
  });
}

/**
 * Get ICP balance for a principal
 * @param principal Principal ID as string
 * @param identityOrAgent Optional identity or Plug agent for authentication
 * @returns Balance in e8s (1 ICP = 100,000,000 e8s)
 */
export async function getICPBalance(
  principal: string,
  identityOrAgent?: IdentityOrAgent
): Promise<bigint> {
  const ledger = await createLedgerActor(identityOrAgent);
  
  const accountId = AccountIdentifier.fromPrincipal({
    principal: Principal.fromText(principal),
  });

  const balance = await ledger.account_balance({
    account: accountId.toUint8Array(),
  });

  return balance.e8s;
}

/**
 * Transfer ICP to another address (principal or account ID)
 * @param identityOrAgent Sender's identity or Plug agent
 * @param to Recipient principal ID or account ID (hex string)
 * @param amountICP Amount in ICP (will be converted to e8s)
 * @returns Transaction block index
 */
export async function transferICP(
  identityOrAgent: IdentityOrAgent,
  to: string,
  amountICP: number
): Promise<bigint> {
  const ledger = await createLedgerActor(identityOrAgent);
  
  // Convert ICP to e8s (1 ICP = 100,000,000 e8s)
  const amountE8s = BigInt(Math.floor(amountICP * 100_000_000));
  
  // Standard ICP transfer fee (0.0001 ICP = 10,000 e8s)
  const feeE8s = BigInt(10_000);
  
  // Try to determine if it's a principal or account ID
  let isPrincipal = false;
  try {
    Principal.fromText(to);
    isPrincipal = true;
  } catch {
    // Not a principal, treat as account ID
    isPrincipal = false;
  }

  if (isPrincipal) {
    // Use ICRC-1 transfer for principal
    const result = await ledger.icrc1_transfer({
      to: {
        owner: Principal.fromText(to),
        subaccount: [],
      },
      fee: [feeE8s],
      memo: [],
      from_subaccount: [],
      created_at_time: [],
      amount: amountE8s,
    });

    if ('Err' in result) {
      throw new Error(`Transfer failed: ${stringifyError(result.Err)}`);
    }

    return result.Ok;
  } else {
    // Use legacy transfer for account ID
    // Convert hex string to Uint8Array
    const accountBytes = new Uint8Array(
      to.match(/.{1,2}/g)!.map(byte => parseInt(byte, 16))
    );

    const result = await ledger.transfer({
      to: accountBytes,
      fee: { e8s: feeE8s },
      memo: BigInt(0),
      from_subaccount: [],
      created_at_time: [],
      amount: { e8s: amountE8s },
    });

    if ('Err' in result) {
      throw new Error(`Transfer failed: ${stringifyError(result.Err)}`);
    }

    return result.Ok;
  }
}

/**
 * Approve a canister to spend ICP on behalf of the user (ICRC-2)
 * @param identityOrAgent User's identity or Plug agent
 * @param spender Canister principal to approve
 * @param amountE8s Amount in e8s to approve
 * @returns Approval block index or error
 */
export async function approveICRC2(
  identityOrAgent: IdentityOrAgent,
  spender: string,
  amountE8s: bigint
): Promise<bigint> {
  console.log('[approveICRC2] Starting approval');
  console.log('[approveICRC2] Spender:', spender);
  console.log('[approveICRC2] Amount:', amountE8s.toString());
  
  const ledger = await createLedgerActor(identityOrAgent);
  console.log('[approveICRC2] Ledger actor created');
  
  const result = await ledger.icrc2_approve({
    spender: {
      owner: Principal.fromText(spender),
      subaccount: [],
    },
    amount: amountE8s,
    fee: [],
    memo: [],
    from_subaccount: [],
    created_at_time: [],
    expected_allowance: [],
    expires_at: [],
  });
  console.log('[approveICRC2] Result:', result);

  if ('Err' in result) {
    console.error('[approveICRC2] Approval failed with error:', result.Err);
    throw new Error(`Approval failed: ${stringifyError(result.Err)}`);
  }

  console.log('[approveICRC2] Approval successful, block:', result.Ok.toString());
  return result.Ok;
}

/**
 * Check current ICRC-2 allowance for a spender
 * @param identityOrAgent User's identity or Plug agent
 * @param spender Canister principal to check allowance for
 * @returns Current allowance in e8s
 */
export async function getAllowance(
  identityOrAgent: IdentityOrAgent,
  spender: string
): Promise<bigint> {
  const ledger = await createLedgerActor(identityOrAgent);
  
  // Get the user's principal
  let ownerPrincipal: Principal;
  if (isPlugAgent(identityOrAgent)) {
    ownerPrincipal = await identityOrAgent.getPrincipal();
  } else {
    ownerPrincipal = identityOrAgent.getPrincipal();
  }
  
  const result = await ledger.icrc2_allowance({
    account: {
      owner: ownerPrincipal,
      subaccount: [],
    },
    spender: {
      owner: Principal.fromText(spender),
      subaccount: [],
    },
  });
  
  return result.allowance;
}

/**
 * Approve allowance with preset amounts
 * @param identityOrAgent User's identity or Plug agent
 * @param spender Canister principal to approve
 * @param amountICP Amount in ICP (will be converted to e8s)
 * @returns Approval block index
 */
export async function setAllowance(
  identityOrAgent: IdentityOrAgent,
  spender: string,
  amountICP: number
): Promise<bigint> {
  const amountE8s = BigInt(Math.floor(amountICP * 100_000_000));
  return approveICRC2(identityOrAgent, spender, amountE8s);
}

/**
 * Clear cached Plug ledger actor (call on logout/disconnect)
 */
export function clearPlugLedgerCache(): void {
  cachedPlugLedgerActor = null;
}
