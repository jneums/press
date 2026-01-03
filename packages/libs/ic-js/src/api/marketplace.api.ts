// import { type Identity, Actor, HttpAgent } from '@icp-sdk/core/agent';
// import { getRacingActor, getNFTsActor, getLedgerActor } from '../actors.js';
// import { PokedBotsRacing, PokedBotsNFTs, Ledger } from '@press/declarations';
// import { Principal } from '@icp-sdk/core/principal';
// import { getCanisterId, getHost } from '../config.js';
// import { sha224 } from 'js-sha256';

// // Helper to safely stringify errors that may contain BigInt
// function stringifyError(err: any): string {
//   try {
//     return JSON.stringify(err, (_, value) =>
//       typeof value === 'bigint' ? value.toString() : value
//     );
//   } catch {
//     return String(err);
//   }
// }

// export interface MarketplaceListing {
//   tokenIndex: number;
//   price: number;
//   faction: string | null;
//   baseSpeed: number;
//   basePowerCore: number;
//   baseAcceleration: number;
//   baseStability: number;
//   currentSpeed?: number; // Present if initialized
//   currentPowerCore?: number; // Present if initialized
//   currentAcceleration?: number; // Present if initialized
//   currentStability?: number; // Present if initialized
//   baseRating: number; // Rating based on base+upgrades (no condition penalty) - used for race class
//   currentRating: number; // Rating with condition/battery penalties
//   overallRating: number; // Same as baseRating for backward compatibility
//   wins: number;
//   racesEntered: number;
//   winRate: number;
//   imageUrl: string;
//   isInitialized: boolean;
//   backgroundColor?: string;
//   battery?: number; // Present if initialized
//   condition?: number; // Present if initialized
// }

// export interface BrowseMarketplaceParams {
//   after?: number;
//   minRating?: number;
//   maxRating?: number;
//   minPrice?: number;
//   maxPrice?: number;
//   faction?: string;
//   raceClass?: string;
//   sortBy?: "price" | "rating" | "index";
//   sortDesc?: boolean;
//   limit?: number;
//   tokenIndex?: string; // Search by token index (partial match)
// }

// export interface BrowseMarketplaceResult {
//   listings: MarketplaceListing[];
//   hasMore: boolean;
// }

// // Accept either Identity or Plug agent
// type IdentityOrAgent = Identity | any;

// // Helper function to detect if this is a Plug agent
// function isPlugAgent(identityOrAgent: any): boolean {
//   return identityOrAgent && 
//          typeof identityOrAgent === 'object' && 
//          'agent' in identityOrAgent &&
//          'getPrincipal' in identityOrAgent &&
//          typeof identityOrAgent.getPrincipal === 'function';
// }

// async function getRacingActorFromIdentity(identityOrAgent: IdentityOrAgent): Promise<PokedBotsRacing._SERVICE> {
//   // Check if it's a Plug agent - use window.ic.plug.createActor
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
//   return getRacingActor(identityOrAgent);
// }

// async function getNFTsActorFromIdentity(identityOrAgent: IdentityOrAgent): Promise<PokedBotsNFTs._SERVICE> {
//   // Check if it's a Plug agent - use window.ic.plug.createActor
//   if (isPlugAgent(identityOrAgent) && typeof globalThis !== 'undefined' && (globalThis as any).window?.ic?.plug?.createActor) {
//     // Check if Plug is still connected before calling createActor (which can trigger popup)
//     const isConnected = await (globalThis as any).window.ic.plug.isConnected();
//     if (!isConnected) {
//       throw new Error('Plug session expired. Please reconnect.');
//     }
//     const canisterId = getCanisterId('POKEDBOTS_NFTS');
//     return await (globalThis as any).window.ic.plug.createActor({
//       canisterId,
//       interfaceFactory: PokedBotsNFTs.idlFactory,
//     });
//   }
//   return getNFTsActor(identityOrAgent);
// }

// async function getLedgerActorFromIdentity(identityOrAgent: IdentityOrAgent): Promise<Ledger._SERVICE> {
//   // Check if it's a Plug agent - use window.ic.plug.createActor
//   if (isPlugAgent(identityOrAgent) && typeof globalThis !== 'undefined' && (globalThis as any).window?.ic?.plug?.createActor) {
//     // Check if Plug is still connected before calling createActor (which can trigger popup)
//     const isConnected = await (globalThis as any).window.ic.plug.isConnected();
//     if (!isConnected) {
//       throw new Error('Plug session expired. Please reconnect.');
//     }
//     const canisterId = getCanisterId('ICP_LEDGER');
//     return await (globalThis as any).window.ic.plug.createActor({
//       canisterId,
//       interfaceFactory: Ledger.idlFactory,
//     });
//   }
//   return getLedgerActor(identityOrAgent);
// }

// // Cache for precomputed stats
// type BotStats = { tokenId: number; speed: number; powerCore: number; acceleration: number; stability: number; faction: string };
// let cachedStats: BotStats[] | null = null;

// // Cache for backgrounds
// type BackgroundData = { backgrounds: Record<string, string> };
// let cachedBackgrounds: BackgroundData | null = null;

// async function loadPrecomputedStats(): Promise<BotStats[]> {
//   if (cachedStats) return cachedStats;
  
//   const response = await fetch('/precomputed-stats.json');
//   const data = await response.json() as { stats: BotStats[] };
//   cachedStats = data.stats;
//   return cachedStats;
// }

// async function loadBackgrounds(): Promise<BackgroundData> {
//   if (cachedBackgrounds) return cachedBackgrounds;
  
//   const response = await fetch('/backgrounds.json');
//   cachedBackgrounds = await response.json() as BackgroundData;
//   return cachedBackgrounds;
// }

// /**
//  * Browse marketplace listings - gets EXT listings then enriches with racing stats from backend
//  */
// export async function browseMarketplace(
//   identityOrAgent: IdentityOrAgent,
//   params: BrowseMarketplaceParams = {}
// ): Promise<BrowseMarketplaceResult> {
//   const nftActor = await getNFTsActorFromIdentity(identityOrAgent);
//   const racingActor = await getRacingActorFromIdentity(identityOrAgent);
//   const nftCanisterId = getCanisterId('POKEDBOTS_NFTS');

//   // Load backgrounds for terrain display
//   const backgroundData = await loadBackgrounds();

//   // Get all listings from EXT canister (fast query call)
//   const extListings = await nftActor.listings();
  
//   if (extListings.length === 0) {
//     return { listings: [], hasMore: false };
//   }

//   // Extract token indices from EXT listings
//   const tokenIndices = extListings.map(([tokenIndex32, _listing, _metadata]: any) => tokenIndex32);

//   // Get enriched data from racing canister (query call with token indices)
//   const enrichedData = await racingActor.get_marketplace_bots_enriched(tokenIndices);
  
//   // Load precomputed stats for faction info on uninitialized bots
//   const precomputedStats = await loadPrecomputedStats();
//   const precomputedMap = new Map(precomputedStats.map(s => [s.tokenId, s]));
  
//   // Create a map of enriched data by token index for quick lookup
//   const enrichedMap = new Map(enrichedData.map((item: any) => [Number(item.tokenIndex), item]));

//   // Merge EXT listings with enriched racing data
//   let enrichedListings: MarketplaceListing[] = extListings.map(([tokenIndex32, listing, _metadata]: any) => {
//     const tokenIndex = Number(tokenIndex32);
//     const priceICP = Number(listing.price) / 100_000_000;
//     const backgroundColor = backgroundData.backgrounds[tokenIndex.toString()];
//     const enriched = enrichedMap.get(tokenIndex);
//     const precomputed = precomputedMap.get(tokenIndex);
    
//     const tokenId = `${tokenIndex}`.padStart(8, '0');
//     const imageUrl = `https://${nftCanisterId}.raw.icp0.io/?tokenid=${nftCanisterId}-${tokenId}&type=thumbnail`;
    
//     // Candid optional types are converted to arrays in JS: [] = null, [value] = Some(value)
//     const racingStats = enriched?.racingStats && Array.isArray(enriched.racingStats) && enriched.racingStats.length > 0 
//       ? enriched.racingStats[0] 
//       : null;
    
//     if (enriched?.isInitialized && racingStats) {
//       // Bot has racing history
//       const stats = racingStats;
//       return {
//         tokenIndex,
//         price: priceICP,
//         faction: stats.faction || precomputed?.faction || null,
//         baseSpeed: Number(stats.baseSpeed || 0),
//         basePowerCore: Number(stats.basePowerCore || 0),
//         baseAcceleration: Number(stats.baseAcceleration || 0),
//         baseStability: Number(stats.baseStability || 0),
//         currentSpeed: Number(stats.currentSpeed || stats.baseSpeed || 0),
//         currentPowerCore: Number(stats.currentPowerCore || stats.basePowerCore || 0),
//         currentAcceleration: Number(stats.currentAcceleration || stats.baseAcceleration || 0),
//         currentStability: Number(stats.currentStability || stats.baseStability || 0),
//         baseRating: Number(stats.baseRating || stats.overallRating || 0),
//         currentRating: Number(stats.currentRating || stats.overallRating || 0),
//         overallRating: Number(stats.baseRating || stats.overallRating || 0),
//         wins: Number(stats.wins || 0),
//         racesEntered: Number(stats.racesEntered || 0),
//         winRate: Number(stats.winRate || 0),
//         imageUrl,
//         isInitialized: true,
//         backgroundColor,
//         battery: Number(stats.battery || 0),
//         condition: Number(stats.condition || 0),
//       };
//     } else if (enriched?.baseStats) {
//       // Uninitialized bot - show base stats and get faction from precomputed data
//       const baseStats = enriched.baseStats;
//       const overallRating = Math.floor((Number(baseStats.speed) + Number(baseStats.powerCore) + Number(baseStats.acceleration) + Number(baseStats.stability)) / 4);
      
//       return {
//         tokenIndex,
//         price: priceICP,
//         faction: precomputed?.faction || null,
//         baseSpeed: Number(baseStats.speed),
//         basePowerCore: Number(baseStats.powerCore),
//         baseAcceleration: Number(baseStats.acceleration),
//         baseStability: Number(baseStats.stability),
//         baseRating: overallRating,
//         currentRating: overallRating,
//         overallRating,
//         wins: 0,
//         racesEntered: 0,
//         winRate: 0,
//         imageUrl,
//         isInitialized: false,
//         backgroundColor,
//       };
//     } else {
//       // Fallback - should not happen but handle gracefully
//       return {
//         tokenIndex,
//         price: priceICP,
//         faction: precomputed?.faction || null,
//         baseSpeed: 0,
//         basePowerCore: 0,
//         baseAcceleration: 0,
//         baseStability: 0,
//         baseRating: 0,
//         currentRating: 0,
//         overallRating: 0,
//         wins: 0,
//         racesEntered: 0,
//         winRate: 0,
//         imageUrl,
//         isInitialized: false,
//         backgroundColor,
//       };
//     }
//   });

//   // Apply filters
//   if (params.minPrice !== undefined) {
//     enrichedListings = enrichedListings.filter(l => l.price >= params.minPrice!);
//   }

//   if (params.maxPrice !== undefined) {
//     enrichedListings = enrichedListings.filter(l => l.price <= params.maxPrice!);
//   }

//   if (params.minRating !== undefined) {
//     enrichedListings = enrichedListings.filter(l => l.overallRating >= params.minRating!);
//   }

//   if (params.maxRating !== undefined) {
//     enrichedListings = enrichedListings.filter(l => l.overallRating <= params.maxRating!);
//   }

//   if (params.faction !== undefined) {
//     enrichedListings = enrichedListings.filter(l => l.faction === params.faction);
//   }

//   if (params.raceClass !== undefined) {
//     enrichedListings = enrichedListings.filter(l => {
//       const rating = l.overallRating;
//       switch (params.raceClass) {
//         case 'SilentKlan': return rating >= 50;
//         case 'Elite': return rating >= 40 && rating < 50;
//         case 'Raider': return rating >= 30 && rating < 40;
//         case 'Junker': return rating >= 20 && rating < 30;
//         case 'Scrap': return rating < 20;
//         default: return true;
//       }
//     });
//   }

//   if (params.tokenIndex !== undefined && params.tokenIndex.trim() !== '') {
//     const searchStr = params.tokenIndex.trim();
//     enrichedListings = enrichedListings.filter(l => 
//       l.tokenIndex.toString().startsWith(searchStr)
//     );
//   }

//   // Apply sorting
//   const sortKey = params.sortBy || 'price';
//   const descending = params.sortDesc !== undefined ? params.sortDesc : (sortKey !== 'price');

//   enrichedListings.sort((a, b) => {
//     let comparison = 0;
//     switch (sortKey) {
//       case 'price':
//         comparison = a.price - b.price;
//         break;
//       case 'rating':
//         comparison = a.overallRating - b.overallRating;
//         break;
//     }
//     return descending ? -comparison : comparison;
//   });

//   // Apply pagination after filtering and sorting
//   const pageSize = params.limit || 20;
//   let startIdx = 0;
  
//   if (params.after !== undefined) {
//     const foundIdx = enrichedListings.findIndex(l => l.tokenIndex === params.after);
//     if (foundIdx !== -1) {
//       startIdx = foundIdx + 1;
//     }
//   }

//   const endIdx = Math.min(startIdx + pageSize, enrichedListings.length);
//   const pageListings = enrichedListings.slice(startIdx, endIdx);

//   return {
//     listings: pageListings,
//     hasMore: endIdx < enrichedListings.length,
//   };
// }

// /**
//  * Browse all bots in the collection (not just marketplace listings)
//  * Uses precomputed stats and enriches with get_bot_profile for each bot
//  */
// export async function browseAllBots(
//   identityOrAgent: IdentityOrAgent,
//   params: BrowseMarketplaceParams = {}
// ): Promise<BrowseMarketplaceResult> {
//   const racingActor = await getRacingActorFromIdentity(identityOrAgent);
//   const nftActor = await getNFTsActorFromIdentity(identityOrAgent);
//   const nftCanisterId = getCanisterId('POKEDBOTS_NFTS');

//   // Load precomputed stats and backgrounds
//   const [precomputedStats, backgroundData, extListings] = await Promise.all([
//     loadPrecomputedStats(),
//     loadBackgrounds(),
//     nftActor.listings()
//   ]);

//   // Create a map of listed prices
//   const priceMap = new Map<number, number>();
//   for (const [tokenIndex32, listing] of extListings) {
//     priceMap.set(Number(tokenIndex32), Number(listing.price) / 100_000_000);
//   }

//   // Apply filters first (before fetching profiles - more efficient)
//   let filteredStats = [...precomputedStats];

//   // Faction filter - normalize faction names (handle "Ultimate-master" vs "UltimateMaster")
//   if (params.faction) {
//     const normalizedFilter = params.faction.toLowerCase().replace(/-/g, '');
//     filteredStats = filteredStats.filter(s => {
//       const normalizedFaction = s.faction.toLowerCase().replace(/-/g, '');
//       return normalizedFaction === normalizedFilter;
//     });
//   }

//   // Rating filter (based on base stats)
//   if (params.minRating !== undefined || params.maxRating !== undefined) {
//     filteredStats = filteredStats.filter(s => {
//       const rating = Math.floor((s.speed + s.powerCore + s.acceleration + s.stability) / 4);
//       if (params.minRating !== undefined && rating < params.minRating) return false;
//       if (params.maxRating !== undefined && rating > params.maxRating) return false;
//       return true;
//     });
//   }

//   // Race class filter
//   if (params.raceClass) {
//     filteredStats = filteredStats.filter(s => {
//       const rating = Math.floor((s.speed + s.powerCore + s.acceleration + s.stability) / 4);
//       switch (params.raceClass) {
//         case 'SilentKlan': return rating >= 50;
//         case 'Elite': return rating >= 40 && rating < 50;
//         case 'Raider': return rating >= 30 && rating < 40;
//         case 'Junker': return rating >= 20 && rating < 30;
//         case 'Scrap': return rating < 20;
//         default: return true;
//       }
//     });
//   }

//   // Token index search
//   if (params.tokenIndex !== undefined && params.tokenIndex.trim() !== '') {
//     const searchStr = params.tokenIndex.trim();
//     filteredStats = filteredStats.filter(s => s.tokenId.toString().startsWith(searchStr));
//   }

//   // Sort the filtered stats
//   const sortKey = params.sortBy || 'rating';
//   // Default: ascending for price (cheap first), descending for rating (best first), ascending for index
//   const descending = params.sortDesc !== undefined 
//     ? params.sortDesc 
//     : (sortKey === 'rating');

//   filteredStats.sort((a, b) => {
//     let comparison = 0;
//     switch (sortKey) {
//       case 'price': {
//         const priceA = priceMap.get(a.tokenId) || 0;
//         const priceB = priceMap.get(b.tokenId) || 0;
//         comparison = priceA - priceB;
//         break;
//       }
//       case 'rating': {
//         const ratingA = Math.floor((a.speed + a.powerCore + a.acceleration + a.stability) / 4);
//         const ratingB = Math.floor((b.speed + b.powerCore + b.acceleration + b.stability) / 4);
//         comparison = ratingA - ratingB;
//         break;
//       }
//       case 'index': {
//         comparison = a.tokenId - b.tokenId;
//         break;
//       }
//     }
//     return descending ? -comparison : comparison;
//   });

//   // Pagination
//   const pageSize = params.limit || 20;
//   let startIdx = 0;
  
//   if (params.after !== undefined) {
//     const foundIdx = filteredStats.findIndex(s => s.tokenId === params.after);
//     if (foundIdx !== -1) {
//       startIdx = foundIdx + 1;
//     }
//   }

//   const endIdx = Math.min(startIdx + pageSize, filteredStats.length);
//   const pageStats = filteredStats.slice(startIdx, endIdx);

//   // Now fetch profiles for this page only
//   const listings: MarketplaceListing[] = await Promise.all(
//     pageStats.map(async (stat) => {
//       const tokenIndex = stat.tokenId;
//       const backgroundColor = backgroundData.backgrounds[tokenIndex.toString()];
//       const tokenId = `${tokenIndex}`.padStart(8, '0');
//       const imageUrl = `https://${nftCanisterId}.raw.icp0.io/?tokenid=${nftCanisterId}-${tokenId}&type=thumbnail`;
//       const price = priceMap.get(tokenIndex) || 0;

//       try {
//         const profile = await racingActor.get_bot_profile(BigInt(tokenIndex));
//         const profileData = profile && profile.length > 0 ? profile[0] : null;

//         if (profileData?.isInitialized && profileData.stats) {
//           // Extract faction safely
//           let factionName = stat.faction;
//           if (profileData.faction && Array.isArray(profileData.faction) && profileData.faction.length > 0) {
//             const factionObj = profileData.faction[0];
//             if (factionObj && typeof factionObj === 'object') {
//               factionName = Object.keys(factionObj)[0];
//             }
//           }
          
//           return {
//             tokenIndex,
//             price,
//             faction: factionName,
//             baseSpeed: Number(stat.speed),
//             basePowerCore: Number(stat.powerCore),
//             baseAcceleration: Number(stat.acceleration),
//             baseStability: Number(stat.stability),
//             currentSpeed: Number(profileData.stats.speed),
//             currentPowerCore: Number(profileData.stats.powerCore),
//             currentAcceleration: Number(profileData.stats.acceleration),
//             currentStability: Number(profileData.stats.stability),
//             baseRating: Number(profileData.stats.overallRating),
//             currentRating: Number(profileData.stats.overallRating),
//             overallRating: Number(profileData.stats.overallRating),
//             wins: Number(profileData.career.wins),
//             racesEntered: Number(profileData.career.racesEntered),
//             winRate: profileData.career.racesEntered > 0 
//               ? (Number(profileData.career.wins) / Number(profileData.career.racesEntered)) * 100 
//               : 0,
//             imageUrl,
//             isInitialized: true,
//             backgroundColor,
//           };
//         }
//       } catch (err) {
//         // If profile fetch fails, fall back to base stats
//       }

//       // Uninitialized or error - use base stats
//       const overallRating = Math.floor((stat.speed + stat.powerCore + stat.acceleration + stat.stability) / 4);
//       return {
//         tokenIndex,
//         price,
//         faction: stat.faction,
//         baseSpeed: stat.speed,
//         basePowerCore: stat.powerCore,
//         baseAcceleration: stat.acceleration,
//         baseStability: stat.stability,
//         baseRating: overallRating,
//         currentRating: overallRating,
//         overallRating,
//         wins: 0,
//         racesEntered: 0,
//         winRate: 0,
//         imageUrl,
//         isInitialized: false,
//         backgroundColor,
//       };
//     })
//   );

//   return {
//     listings,
//     hasMore: endIdx < filteredStats.length,
//   };
// }

// /**
//  * Purchase a PokedBot from the EXT marketplace
//  * Follows the EXT standard: lock -> transfer ICP -> settle
//  */
// export async function purchaseMarketplaceBot(
//   identityOrAgent: IdentityOrAgent,
//   tokenIndex: number,
//   priceICP: number
// ): Promise<string> {
//   const nftActor = await getNFTsActorFromIdentity(identityOrAgent);
//   const ledgerActor = await getLedgerActorFromIdentity(identityOrAgent);
  
//   // Get buyer's principal and convert to account identifier
//   let buyerPrincipal: Principal;
//   if (identityOrAgent && typeof identityOrAgent === 'object' && 'getPrincipal' in identityOrAgent) {
//     buyerPrincipal = await identityOrAgent.getPrincipal();
//   } else {
//     buyerPrincipal = (identityOrAgent as Identity).getPrincipal();
//   }
  
//   // Generate token identifier
//   const nftCanisterId = getCanisterId('POKEDBOTS_NFTS');
//   const tokenId = generateTokenIdentifier(nftCanisterId, tokenIndex);
  
//   // Convert principal to account identifier (EXT format)
//   const buyerAccountId = principalToAccountIdentifier(buyerPrincipal);
  
//   // Step 1: Lock the NFT
//   const lockResult = await nftActor.lock(
//     tokenId,
//     BigInt(priceICP * 100_000_000),
//     buyerAccountId, // buyer's account identifier
//     []  // subaccount
//   );

//   if ('err' in lockResult) {
//     throw new Error(`Failed to lock NFT: ${stringifyError(lockResult.err)}`);
//   }

//   const paymentAddress = lockResult.ok;

//   // Step 2: Transfer ICP to payment address (account identifier)
//   // Convert hex string to Uint8Array for the transfer
//   const paymentAddressBytes = hexToUint8Array(paymentAddress);
  
//   // Use legacy transfer for account identifier (not ICRC-1)
//   const transferResult = await (ledgerActor as any).transfer({
//     to: paymentAddressBytes,
//     fee: { e8s: BigInt(10_000) }, // Standard ICP fee
//     memo: BigInt(0),
//     from_subaccount: [],
//     created_at_time: [],
//     amount: { e8s: BigInt(priceICP * 100_000_000) },
//   });

//   if ('Err' in transferResult) {
//     throw new Error(`Failed to transfer ICP: ${stringifyError(transferResult.Err)}`);
//   }

//   // Step 3: Settle the purchase to complete ownership transfer
//   try {
//     await nftActor.settle(tokenId);
//   } catch (e) {
//     // Settlement might fail if already processed, but that's OK
//     console.warn('Settlement call failed (might already be settled):', e);
//   }

//   return `Successfully purchased Bot #${tokenIndex}!`;
// }

// /**
//  * Convert hex string to Uint8Array (browser-compatible)
//  */
// function hexToUint8Array(hex: string): Uint8Array {
//   // Remove any non-hex characters
//   const cleanHex = hex.replace(/[^0-9a-fA-F]/g, '');
//   if (cleanHex.length % 2 !== 0) {
//     throw new Error(`Invalid hex string length: ${cleanHex.length}`);
//   }
//   const bytes = new Uint8Array(cleanHex.length / 2);
//   for (let i = 0; i < cleanHex.length; i += 2) {
//     bytes[i / 2] = parseInt(cleanHex.substring(i, i + 2), 16);
//   }
//   return bytes;
// }

// /**
//  * Generate EXT token identifier from canister ID and token index
//  */
// function generateTokenIdentifier(canisterId: string, tokenIndex: number): string {
//   // Create padding: [0x0A, 't', 'i', 'd']
//   const padding = new Uint8Array([0x0A, 0x74, 0x69, 0x64]);
//   const array = new Uint8Array([
//     ...padding,
//     ...Principal.fromText(canisterId).toUint8Array(),
//     ...to32bits(tokenIndex),
//   ]);
//   return Principal.fromUint8Array(array).toText();
// }

// function to32bits(num: number): Uint8Array {
//   const b = new ArrayBuffer(4);
//   new DataView(b).setUint32(0, num);
//   return new Uint8Array(b);
// }

// /**
//  * Convert principal to account identifier (EXT format)
//  */
// function principalToAccountIdentifier(principal: Principal, subaccount?: Uint8Array): string {
//   // Create padding: [0x0A, 'a', 'c', 'c', 'o', 'u', 'n', 't', '-', 'i', 'd']
//   const padding = new Uint8Array([0x0A, 0x61, 0x63, 0x63, 0x6F, 0x75, 0x6E, 0x74, 0x2D, 0x69, 0x64]);
//   const array = new Uint8Array([
//     ...padding,
//     ...principal.toUint8Array(),
//     ...(subaccount || new Uint8Array(32)),
//   ]);
//   const hash = sha224(array);
//   const hashBytes = hexToUint8Array(hash);
//   const checksum = to32bits(crc32(hashBytes));
//   const bytes = new Uint8Array([...checksum, ...hashBytes]);
//   return Array.from(bytes)
//     .map(b => b.toString(16).padStart(2, '0'))
//     .join('');
// }

// function crc32(buf: Uint8Array): number {
//   const table = new Uint32Array(256);
//   for (let i = 0; i < 256; i++) {
//     let c = i;
//     for (let j = 0; j < 8; j++) {
//       c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
//     }
//     table[i] = c;
//   }
//   let crc = 0xffffffff;
//   for (let i = 0; i < buf.length; i++) {
//     crc = table[(crc ^ buf[i]) & 0xff] ^ (crc >>> 8);
//   }
//   return (crc ^ 0xffffffff) >>> 0;
// }

// /**
//  * List a bot for sale on the marketplace
//  * @param tokenIndex The token index of the bot to list
//  * @param priceICP Price in ICP
//  * @param identityOrAgent User's identity or agent
//  * @returns Success message or error
//  */
// export async function listBotForSale(
//   tokenIndex: number,
//   priceICP: number,
//   identityOrAgent: IdentityOrAgent
// ): Promise<string> {
//   const nftsActor = await getNFTsActorFromIdentity(identityOrAgent);
//   const nftCanisterId = getCanisterId('pokedbots_nfts');
  
//   // Generate token identifier
//   const tokenId = generateTokenIdentifier(nftCanisterId, tokenIndex);
  
//   // Convert ICP to e8s
//   const priceE8s = BigInt(Math.floor(priceICP * 100_000_000));
  
//   const result = await nftsActor.list({
//     token: tokenId,
//     from_subaccount: [],
//     price: [priceE8s],
//   });
  
//   if ('ok' in result) {
//     return `Bot #${tokenIndex} listed for ${priceICP} ICP`;
//   } else {
//     throw new Error(`Failed to list bot: ${result.err}`);
//   }
// }

// /**
//  * Remove a bot listing from the marketplace
//  * @param tokenIndex The token index of the bot to unlist
//  * @param identityOrAgent User's identity or agent
//  * @returns Success message or error
//  */
// export async function unlistBot(
//   tokenIndex: number,
//   identityOrAgent: IdentityOrAgent
// ): Promise<string> {
//   const nftsActor = await getNFTsActorFromIdentity(identityOrAgent);
//   const nftCanisterId = getCanisterId('pokedbots_nfts');
  
//   // Generate token identifier
//   const tokenId = generateTokenIdentifier(nftCanisterId, tokenIndex);
  
//   // List with no price to remove listing
//   const result = await nftsActor.list({
//     token: tokenId,
//     from_subaccount: [],
//     price: [],
//   });
  
//   if ('ok' in result) {
//     return `Bot #${tokenIndex} removed from marketplace`;
//   } else {
//     throw new Error(`Failed to unlist bot: ${result.err}`);
//   }
// }

// /**
//  * Transfer a bot to another account
//  * @param tokenIndex The token index of the bot to transfer
//  * @param to Recipient principal ID or account ID (hex string)
//  * @param identityOrAgent User's identity or agent
//  * @returns Success message or error
//  */
// export async function transferBot(
//   tokenIndex: number,
//   to: string,
//   identityOrAgent: IdentityOrAgent
// ): Promise<string> {
//   const nftsActor = await getNFTsActorFromIdentity(identityOrAgent);
//   const nftCanisterId = getCanisterId('pokedbots_nfts');
  
//   // Generate token identifier
//   const tokenId = generateTokenIdentifier(nftCanisterId, tokenIndex);
  
//   // Get caller's principal for "from" user
//   let callerPrincipal: Principal;
//   if (identityOrAgent && typeof identityOrAgent === 'object' && 'getPrincipal' in identityOrAgent) {
//     callerPrincipal = await identityOrAgent.getPrincipal();
//   } else {
//     callerPrincipal = identityOrAgent.getPrincipal();
//   }
  
//   // Determine if 'to' is a principal or account ID
//   let toUser: { principal: Principal } | { address: string };
//   try {
//     // Try to parse as principal (format: xxxxx-xxxxx-xxxxx-xxxxx-cai)
//     const principal = Principal.fromText(to);
//     toUser = { principal };
//   } catch {
//     // If not a principal, treat as account ID (hex string)
//     toUser = { address: to };
//   }
  
//   const result = await nftsActor.transfer({
//     token: tokenId,
//     from: { principal: callerPrincipal },
//     to: toUser,
//     amount: BigInt(1),
//     memo: new Uint8Array([]),
//     notify: false,
//     subaccount: [],
//   });
  
//   if ('ok' in result) {
//     return `Bot #${tokenIndex} transferred successfully`;
//   } else {
//     const errMsg = 'err' in result ? stringifyError(result.err) : 'Unknown error';
//     throw new Error(`Failed to transfer bot: ${errMsg}`);
//   }
// }
