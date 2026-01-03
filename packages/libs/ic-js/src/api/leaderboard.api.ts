// // packages/libs/ic-js/src/api/leaderboard.api.ts

// import { Identity } from '@icp-sdk/core/agent';
// import { getRacingActor } from '../actors.js';
// import { PokedBotsRacing } from '@press/declarations';

// export type LeaderboardEntry = PokedBotsRacing.LeaderboardEntry;
// export type LeaderboardType = PokedBotsRacing.LeaderboardType;

// /**
//  * Fetches the leaderboard for a specific type (Monthly, Season, AllTime, Faction, or Division).
//  * @param lbType The type of leaderboard to fetch
//  * @param limit Maximum number of entries to return
//  * @param bracket Optional race class/bracket filter
//  * @param identity Optional identity to use for the actor
//  * @returns An array of LeaderboardEntry objects, sorted by rank
//  */
// export const getLeaderboard = async (
//   lbType: LeaderboardType,
//   limit: number = 100,
//   bracket?: PokedBotsRacing.RaceClass,
//   identity?: Identity
// ): Promise<LeaderboardEntry[]> => {
//   const racingActor = await getRacingActor(identity);
//   const result = await racingActor.get_leaderboard(lbType, BigInt(limit), bracket ? [bracket] : []);
//   return result;
// };

// /**
//  * Fetches the ranking for a specific bot on a given leaderboard.
//  * @param lbType The type of leaderboard to query
//  * @param tokenIndex The token index of the bot
//  * @param identity Optional identity to use for the actor
//  * @returns The LeaderboardEntry for the bot, or null if not found
//  */
// export const getMyRanking = async (
//   lbType: LeaderboardType,
//   tokenIndex: number,
//   identity?: Identity
// ): Promise<LeaderboardEntry | null> => {
//   const racingActor = await getRacingActor(identity);
//   const result = await racingActor.get_my_ranking(lbType, BigInt(tokenIndex));
//   return result.length > 0 ? (result[0] ?? null) : null;
// };

// /**
//  * Gets the current season and month IDs from the backend.
//  * @param identity Optional identity to use for the actor
//  */
// export const getCurrentPeriods = async (
//   identity?: Identity
// ): Promise<{ seasonId: bigint; monthId: bigint }> => {
//   const racingActor = await getRacingActor(identity);
//   return await racingActor.get_current_periods();
// };

// /**
//  * Gets the monthly leaderboard (current month).
//  * @param limit Maximum number of entries to return
//  * @param bracket Optional race class/bracket filter
//  * @param identity Optional identity to use for the actor
//  */
// export const getMonthlyLeaderboard = async (
//   limit: number = 50,
//   bracket?: PokedBotsRacing.RaceClass,
//   identity?: Identity
// ): Promise<LeaderboardEntry[]> => {
//   const { monthId } = await getCurrentPeriods(identity);
//   return getLeaderboard({ Monthly: monthId }, limit, bracket, identity);
// };

// /**
//  * Gets the season leaderboard (current season).
//  * @param limit Maximum number of entries to return
//  * @param bracket Optional race class/bracket filter
//  * @param identity Optional identity to use for the actor
//  */
// export const getSeasonLeaderboard = async (
//   limit: number = 50,
//   bracket?: PokedBotsRacing.RaceClass,
//   identity?: Identity
// ): Promise<LeaderboardEntry[]> => {
//   const { seasonId } = await getCurrentPeriods(identity);
//   return getLeaderboard({ Season: seasonId }, limit, bracket, identity);
// };

// /**
//  * Gets the all-time leaderboard.
//  * @param limit Maximum number of entries to return
//  * @param bracket Optional race class/bracket filter
//  * @param identity Optional identity to use for the actor
//  */
// export const getAllTimeLeaderboard = async (
//   limit: number = 100,
//   bracket?: PokedBotsRacing.RaceClass,
//   identity?: Identity
// ): Promise<LeaderboardEntry[]> => {
//   return getLeaderboard({ AllTime: null }, limit, bracket, identity);
// };

// /**
//  * Gets the faction leaderboard for a specific faction.
//  * @param faction The faction to get the leaderboard for
//  * @param limit Maximum number of entries to return
//  * @param bracket Optional race class/bracket filter
//  * @param identity Optional identity to use for the actor
//  */
// export const getFactionLeaderboard = async (
//   faction: PokedBotsRacing.FactionType,
//   limit: number = 50,
//   bracket?: PokedBotsRacing.RaceClass,
//   identity?: Identity
// ): Promise<LeaderboardEntry[]> => {
//   return getLeaderboard({ Faction: faction }, limit, bracket, identity);
// };
