// import { type Identity } from '@icp-sdk/core/agent';
// import { getRacingActor } from '../actors.js';
// import { PokedBotsRacing } from '@press/declarations';
// import { getCanisterId } from '../config.js';

// export type BetType = 'Win' | 'Place' | 'Show';

// // Accept either Identity or Plug agent (both optional)
// type IdentityOrAgent = Identity | any | undefined;

// // Helper function to detect if this is a Plug agent
// function isPlugAgent(identityOrAgent: any): boolean {
//   return identityOrAgent && 
//          typeof identityOrAgent === 'object' && 
//          'agent' in identityOrAgent &&
//          'getPrincipal' in identityOrAgent &&
//          typeof identityOrAgent.getPrincipal === 'function';
// }

// // Helper to get racing actor
// async function getActor(identityOrAgent?: IdentityOrAgent): Promise<PokedBotsRacing._SERVICE> {
//   if (isPlugAgent(identityOrAgent) && typeof globalThis !== 'undefined' && (globalThis as any).window?.ic?.plug?.createActor) {
//     // Check if Plug is still connected before calling createActor (which can trigger popup)
//     const isConnected = await (globalThis as any).window.ic.plug.isConnected();
//     if (!isConnected) {
//       throw new Error('Plug session expired. Please reconnect.');
//     }
//     const canisterId = getCanisterId('press');
//     return await (globalThis as any).window.ic.plug.createActor({
//       canisterId,
//       interfaceFactory: PokedBotsRacing.idlFactory,
//     });
//   }
//   return getRacingActor(identityOrAgent as Identity | undefined);
// }

// export interface BettingPoolInfo {
//   race_id: number;
//   raceId: number;  // Backend uses this
//   status: string;
//   time_info?: string;
//   race_class?: string;
//   raceClass: string;  // Backend uses this
//   distance_km?: number;
//   distance: bigint;  // Backend uses this
//   terrain: string;
//   entrants_count?: number;
//   entrants: bigint[];  // Backend uses this
//   total_pool_icp?: string;
//   totalPooled: bigint;  // Backend uses this (in e8s)
//   win_pool_icp?: string;
//   winPool: bigint;  // Backend uses this
//   place_pool_icp?: string;
//   placePool: bigint;  // Backend uses this
//   show_pool_icp?: string;
//   showPool: bigint;  // Backend uses this
//   total_bets?: number;
//   betIds: bigint[];  // Backend uses this
//   bettingOpensAt: bigint;
//   betting_opens_at?: bigint;
//   bettingClosesAt: bigint;
//   betting_closes_at?: bigint;
//   entrant_odds?: EntrantOdds[];
//   winBetsByBot: [bigint, bigint][];  // Backend uses this
//   placeBetsByBot: [bigint, bigint][];  // Backend uses this
//   showBetsByBot: [bigint, bigint][];  // Backend uses this
//   results?: any | null;
//   payoutsCompleted: boolean;
//   payouts_completed?: boolean;
//   failedPayouts: bigint[];
//   failed_payouts_count?: number;
//   rakeDistributed: boolean;
//   subaccount: Uint8Array;
// }

// export interface EntrantOdds {
//   token_index: number;
//   win_odds: string;
//   place_odds: string;
//   show_odds: string;
//   win_pool_icp: string;
//   place_pool_icp: string;
//   show_pool_icp: string;
// }

// export interface Bet {
//   bet_id: number;
//   race_id: number;
//   token_index: number;
//   bet_type: string;
//   amount_icp: string;
//   amount_e8s: number;
//   status: string;
//   timestamp: number;
//   payout: [] | [{
//     payout_icp: string;
//     payout_e8s: number;
//     roi_percent: string;
//   }];
// }

// export interface MyBetsResponse {
//   bets: Bet[];
//   count: number;
//   summary: {
//     total_bets: number;
//     wins: number;
//     losses: number;
//     pending: number;
//     total_wagered_icp: string;
//     total_won_icp: string;
//     net_profit_icp: string;
//     roi_percent: string;
//     win_rate_percent: string;
//   };
// }

// export interface MyBetsPaginatedResponse {
//   bets: Bet[];
//   hasMore: boolean;
//   total: number;
//   summary: {
//     total_bets: number;
//     wins: number;
//     losses: number;
//     pending: number;
//     total_wagered_icp: string;
//     total_won_icp: string;
//     net_profit_icp: string;
//     roi_percent: string;
//     win_rate_percent: string;
//   };
// }

// export interface PlaceBetResponse {
//   success: boolean;
//   bet_id: number;
//   race_id: number;
//   token_index: number;
//   bet_type: string;
//   amount_icp: string;
//   amount_e8s: number;
//   current_odds: string;
//   potential_payout_icp: string;
//   block_index: number;
//   message: string;
// }

// export interface BettingPool {
//   race_id: number;
//   status: string;
//   race_class: string;
//   distance_km: number;
//   terrain: string;
//   entrants_count: number;
//   total_pool_icp: string;
//   total_bets: number;
//   betting_opens_at: bigint;
//   betting_closes_at: bigint;
// }

// export interface ListPoolsResponse {
//   pools: BettingPool[];
//   count: number;
// }

// /**
//  * Get detailed betting pool information for a race
//  */
// export async function bettingGetPoolInfo(
//   identityOrAgent: IdentityOrAgent | undefined,
//   raceId: number
// ): Promise<BettingPoolInfo | null> {
//   const actor = await getActor(identityOrAgent);
//   const response = await actor.web_betting_get_pool_info(BigInt(raceId));
//   return response ? (response as unknown as BettingPoolInfo) : null;
// }

// /**
//  * Get user's betting history
//  */
// export async function bettingGetMyBets(
//   identityOrAgent: IdentityOrAgent,
//   limit: number = 50
// ): Promise<MyBetsResponse> {
//   const actor = await getActor(identityOrAgent);
//   const response = await actor.web_betting_get_my_bets(BigInt(limit));
//   return response as unknown as MyBetsResponse;
// }

// /**
//  * Get user's betting history with pagination
//  */
// export async function bettingGetMyBetsPaginated(
//   identityOrAgent: IdentityOrAgent,
//   limit: number = 10,
//   offset: number = 0
// ): Promise<MyBetsPaginatedResponse> {
//   const actor = await getActor(identityOrAgent);
//   const response = await actor.web_betting_get_my_bets_paginated(BigInt(limit), BigInt(offset));
//   return response as unknown as MyBetsPaginatedResponse;
// }

// /**
//  * Place a bet on a race
//  */
// export async function bettingPlaceBet(
//   identityOrAgent: IdentityOrAgent,
//   raceId: number,
//   tokenIndex: number,
//   betType: BetType,
//   amountIcp: number
// ): Promise<PlaceBetResponse> {
//   const actor = await getActor(identityOrAgent);
//   const amountE8s = BigInt(Math.floor(amountIcp * 100_000_000));
  
//   const result = await actor.web_betting_place_bet(
//     BigInt(raceId),
//     BigInt(tokenIndex),
//     { [betType]: null } as any, // Motoko variant
//     amountE8s
//   );
  
//   if ('ok' in result) {
//     const data = result.ok;
//     return {
//       success: true,
//       bet_id: Number(data.betId),
//       race_id: raceId,
//       token_index: tokenIndex,
//       bet_type: betType,
//       amount_icp: amountIcp.toFixed(2),
//       amount_e8s: Number(amountE8s),
//       current_odds: Number(data.currentOdds).toFixed(2),
//       potential_payout_icp: (Number(data.potentialPayout) / 100_000_000).toFixed(2),
//       block_index: 0, // Not returned from web method
//       message: `Bet placed successfully! Current odds: ${Number(data.currentOdds).toFixed(2)}x`
//     };
//   } else {
//     throw new Error(result.err);
//   }
// }

// /**
//  * List betting pools
//  */
// export async function bettingListPools(
//   identityOrAgent: IdentityOrAgent,
//   limit: number = 20,
//   statusFilter?: string
// ): Promise<ListPoolsResponse> {
//   const actor = await getActor(identityOrAgent);
//   // TODO: Implement web_betting_list_pools on canister side
//   throw new Error('web_betting_list_pools not yet implemented');
// }
