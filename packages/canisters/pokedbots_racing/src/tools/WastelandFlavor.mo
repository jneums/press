import PokedBotsGarage "../PokedBotsGarage";

module {
  // Get faction-specific flavor text for various events
  public func getFactionGreeting(faction : PokedBotsGarage.FactionType) : Text {
    switch (faction) {
      // Ultra-Rare
      case (#UltimateMaster) { "👑 **SUPREME MASTERY ACHIEVED**" };
      case (#Wild) { "🦾 **FERAL CIRCUITS ONLINE**" };
      case (#Golden) { "✨ **PRISTINE SYSTEMS INITIALIZED**" };
      case (#Ultimate) { "⚡ **ULTIMATE PROTOCOLS EXECUTING**" };
      // Super-Rare
      case (#Blackhole) { "🌌 **VOID ENGINES ACTIVE**" };
      case (#Dead) { "💀 **NECRO-MECHANICAL SYSTEMS ONLINE**" };
      case (#Master) { "🎯 **MASTER PROTOCOLS EXECUTING**" };
      // Rare
      case (#Bee) { "🐝 **HIVE MIND SYNCHRONIZED**" };
      case (#Food) { "🍔 **SUSTENANCE PROTOCOLS ENGAGED**" };
      case (#Box) { "📦 **CONTAINMENT SYSTEMS ACTIVE**" };
      case (#Murder) { "🔪 **LETHAL SUBROUTINES LOADED**" };
      // Common
      case (#Game) { "🎮 **GAME LOGIC INITIALIZED**" };
      case (#Animal) { "🦎 **INSTINCT DRIVERS ONLINE**" };
      case (#Industrial) { "⚙️ **UTILITY SYSTEMS READY**" };
    };
  };

  public func getStatusFlavor(status : Text, faction : PokedBotsGarage.FactionType) : Text {
    if (status == "Critical Malfunction") {
      switch (faction) {
        case (#UltimateMaster) {
          "👑 **SUPREME FAILURE** - Even mastery cannot prevent catastrophic failure";
        };
        case (#Wild) {
          "🔥 **SYSTEMS DYING** - Chaotic failures across all circuits";
        };
        case (#Golden) {
          "✨ **TARNISHED PERFECTION** - Golden systems compromised";
        };
        case (#Ultimate) {
          "⚡ **ULTIMATE COLLAPSE** - Critical systems offline";
        };
        case (#Blackhole) { "🌌 **VOID BREACH** - Dimensional engines failing" };
        case (#Dead) { "💀 **FINAL DEATH** - Necro-systems shutting down" };
        case (#Master) {
          "🚨 **MASTER OVERRIDE REQUIRED** - Emergency protocols engaged";
        };
        case (#Bee) { "🐝 **HIVE COLLAPSE** - Swarm intelligence fragmenting" };
        case (#Food) {
          "🍔 **SUSTENANCE FAILURE** - Energy distribution critical";
        };
        case (#Box) {
          "📦 **CONTAINMENT BREACH** - Structural integrity failing";
        };
        case (#Murder) { "🔪 **LETHAL MALFUNCTION** - Weapon systems offline" };
        case (#Game) { "🎮 **GAME OVER** - Core logic systems corrupted" };
        case (#Animal) { "🦎 **INSTINCT FAILURE** - Survival protocols down" };
        case (#Industrial) {
          "⚙️ **TOTAL BREAKDOWN** - All utility functions offline";
        };
      };
    } else if (status == "Needs Repair") {
      switch (faction) {
        case (#UltimateMaster) {
          "👑 **SUPREME MAINTENANCE** - Perfection requires constant care";
        };
        case (#Wild) {
          "⚙️ **SCRAP PARTS FAILING** - Salvaged components breaking down";
        };
        case (#Golden) {
          "✨ **MINOR IMPERFECTIONS** - Beneath our standards. Golden bots need 90%+ condition for +15% stat bonus!";
        };
        case (#Ultimate) {
          "⚡ **WEAR DETECTED** - Ultimate systems need tuning";
        };
        case (#Blackhole) {
          "🌌 **VOID DEGRADATION** - Dimensional stress accumulating";
        };
        case (#Dead) { "💀 **DECAY DETECTED** - Necro-systems need refresh" };
        case (#Master) {
          "📋 **SCHEDULED MAINTENANCE** - Optimal performance requires care";
        };
        case (#Bee) { "🐝 **HIVE DAMAGE** - Swarm components need repair" };
        case (#Food) { "🍔 **NUTRITION LOW** - Energy systems degrading" };
        case (#Box) {
          "📦 **STRUCTURAL WEAR** - Containment integrity compromised. Box bots get +10% on ScrapHeaps!";
        };
        case (#Murder) { "🔪 **EDGE DULLED** - Weapon systems need sharpening" };
        case (#Game) {
          "🎮 **LAG DETECTED** - Game logic needs optimization. Game bots excel on WastelandSand (+8%)!";
        };
        case (#Animal) {
          "🦎 **WEAR AND TEAR** - Natural degradation occurring";
        };
        case (#Industrial) {
          "⚙️ **SERVICE DUE** - Standard maintenance required";
        };
      };
    } else if (status == "Low Battery") {
      switch (faction) {
        case (#UltimateMaster) {
          "🌟 **SUPREME POWER LOW** - Even mastery needs energy";
        };
        case (#Wild) {
          "⚡ **RUNNING ON FUMES** - Chaotic energy nearly exhausted";
        };
        case (#Golden) {
          "🌟 **GOLDEN GLOW FADING** - Pristine power reserves low";
        };
        case (#Ultimate) {
          "⚡ **ULTIMATE CHARGE LOW** - Power cells depleting";
        };
        case (#Blackhole) {
          "🌌 **VOID ENERGY LOW** - Dimensional power reserves depleting. Higher Power Core stat = better void energy efficiency on MetalRoads!";
        };
        case (#Dead) {
          "💀 **LIFE FORCE LOW** - Necro-energy depleted. Strong Power Core extends necro-system runtime!";
        };
        case (#Master) {
          "📊 **POWER OPTIMIZATION NEEDED** - Efficiency dropping";
        };
        case (#Bee) { "🐝 **HIVE ENERGY LOW** - Swarm power diminishing" };
        case (#Food) { "🍔 **HUNGER DETECTED** - Sustenance reserves critical" };
        case (#Box) { "📦 **BATTERY BOXED OUT** - Stored energy depleted" };
        case (#Murder) { "🔪 **KILLING CHARGE LOW** - Attack power fading" };
        case (#Game) { "🎮 **BATTERY DRAINING** - Need power-up" };
        case (#Animal) { "🦎 **ENERGY DEPLETED** - Natural reserves exhausted" };
        case (#Industrial) { "⚙️ **POWER LOW** - Standard recharge needed" };
      };
    } else if (status == "Ready") {
      switch (faction) {
        case (#UltimateMaster) {
          "👑 **SUPREME READINESS** - Mastery at peak performance";
        };
        case (#Wild) {
          "🔥 **WILD AND READY** - Chaos incarnate, primed for action";
        };
        case (#Golden) { "✨ **PRISTINE PERFECTION** - Golden systems optimal" };
        case (#Ultimate) { "⚡ **ULTIMATE READY** - All systems at maximum" };
        case (#Blackhole) {
          "🌌 **VOID READY** - Dimensional engines primed. +12% performance on MetalRoads terrain!";
        };
        case (#Dead) {
          "💀 **UNDEAD READY** - Necro-systems fully charged. Enhanced Power Core resilience!";
        };
        case (#Master) {
          "🎯 **OPTIMAL STATUS** - All systems green, ready for deployment";
        };
        case (#Bee) { "🐝 **SWARM READY** - Hive mind synchronized" };
        case (#Food) { "🍔 **WELL FED** - Energy systems fully charged" };
        case (#Box) { "📦 **SEALED AND READY** - Containment optimal" };
        case (#Murder) { "🔪 **ARMED AND READY** - Lethal systems primed" };
        case (#Game) { "🎮 **PLAYER 1 READY** - Game logic optimal" };
        case (#Animal) { "🦎 **INSTINCT PRIMED** - Natural systems ready" };
        case (#Industrial) { "⚙️ **OPERATIONAL** - All functions nominal" };
      };
    } else {
      switch (faction) {
        case (#UltimateMaster) {
          "👑 **BELOW SUPREME STANDARDS** - Mastery requires perfection";
        };
        case (#Wild) { "🦾 **NEEDS ATTENTION** - Even wild machines need care" };
        case (#Golden) {
          "✨ **BELOW STANDARDS** - Perfection demands maintenance";
        };
        case (#Ultimate) {
          "⚡ **SUBOPTIMAL** - Ultimate performance requires care";
        };
        case (#Blackhole) {
          "🌌 **VOID DRIFT** - Dimensional calibration needed";
        };
        case (#Dead) { "💀 **DEGRADING** - Necro-systems need refresh" };
        case (#Master) {
          "📋 **SERVICE DUE** - Scheduled maintenance recommended";
        };
        case (#Bee) { "🐝 **HIVE NEEDS CARE** - Swarm efficiency dropping" };
        case (#Food) { "🍔 **NEEDS FEEDING** - Energy optimization required" };
        case (#Box) { "📦 **NEEDS SERVICE** - Containment check required" };
        case (#Murder) { "🔪 **NEEDS SHARPENING** - Weapon efficiency down" };
        case (#Game) { "🎮 **NEEDS UPDATE** - Game logic optimization due" };
        case (#Animal) { "🦎 **NEEDS CARE** - Natural maintenance required" };
        case (#Industrial) {
          "⚙️ **MAINTENANCE REQUIRED** - Service recommended";
        };
      };
    };
  };

  public func getUpgradeFlavor(upgradeType : PokedBotsGarage.UpgradeType, faction : PokedBotsGarage.FactionType) : Text {
    let baseText = switch (upgradeType) {
      case (#Velocity) { "⚡ **VELOCITY MODULE**" };
      case (#PowerCore) { "🔋 **POWER CORE**" };
      case (#Thruster) { "🚀 **THRUSTER ARRAY**" };
      case (#Gyro) { "🎯 **GYRO STABILIZER**" };
    };

    let factionNote = switch (faction) {
      case (#UltimateMaster) { " - Supreme technology, unmatched quality" };
      case (#Wild) { " - Unstable but powerful wasteland salvage" };
      case (#Golden) { " - Pristine components, golden standard" };
      case (#Ultimate) { " - Ultimate-grade parts, maximum performance" };
      case (#Blackhole) { " - Void-touched technology from beyond" };
      case (#Dead) { " - Necro-engineered from ancient machines" };
      case (#Master) { " - Precision-engineered from ancient blueprints" };
      case (#Bee) { " - Hive-optimized swarm components" };
      case (#Food) { " - Energy-efficient sustenance systems" };
      case (#Box) { " - Compact, efficient containment tech" };
      case (#Murder) { " - Lethal-grade combat components" };
      case (#Game) { " - Logic-optimized processing modules" };
      case (#Animal) { " - Instinct-enhanced natural parts" };
      case (#Industrial) { " - Standard wasteland salvage" };
    };

    baseText # factionNote;
  };

  public func getReputationTier(reputation : Nat) : Text {
    if (reputation == 0) {
      "🔰 **UNKNOWN** - No reputation in the wasteland";
    } else if (reputation < 10) {
      "🌑 **SCAVENGER** - Fresh to the wasteland circuit";
    } else if (reputation < 25) {
      "🌒 **SALVAGER** - Making a name in the scrap heaps";
    } else if (reputation < 50) {
      "🌓 **RAIDER** - Respected among the wasteland gangs";
    } else if (reputation < 100) {
      "🌔 **VETERAN** - Battle-hardened and proven";
    } else if (reputation < 200) {
      "🌕 **CHAMPION** - Legend of the wasteland tracks";
    } else {
      "💫 **WASTELAND LEGEND** - Name spoken in hushed tones at Delta City";
    };
  };

  public func getDecayMessage(faction : PokedBotsGarage.FactionType) : Text {
    switch (faction) {
      case (#UltimateMaster) { "👑 Supreme construction resists decay (-40%)" };
      case (#Wild) {
        "🔥 The chaos within accelerates decay - Wild Bots degrade 30% faster!";
      };
      case (#Golden) { "✨ Pristine construction resists decay better (-30%)" };
      case (#Ultimate) { "⚡ Ultimate engineering reduces decay (-25%)" };
      case (#Blackhole) { "🌌 Void technology resists degradation (-15%)" };
      case (#Dead) { "💀 Necro-systems resist natural decay (-15%)" };
      case (#Master) { "📋 Precision engineering maintains integrity (-15%)" };
      case (#Bee) { "🐝 Hive maintenance protocols slow decay (-5%)" };
      case (#Food) { "🍔 Energy-efficient systems reduce wear (-5%)" };
      case (#Box) { "📦 Sealed systems protect from decay (-5%)" };
      case (#Murder) { "🔪 Combat-grade parts resist wear (-5%)" };
      case (#Game) { "🎮 Game logic maintains system integrity" };
      case (#Animal) { "🦎 Natural systems adapt to decay" };
      case (#Industrial) { "⚙️ Standard decay rates apply" };
    };
  };

  public func getWastelandQuote() : Text {
    let quotes = [
      "💀 \"In the wasteland, only the strongest circuits survive.\" - Delta City Mechanic",
      "⚡ \"Race fast, die young, leave a rusty chassis.\" - Wild Bot Proverb",
      "👑 \"We are the masters of steel. We are perfection.\" - Ultimate Manifesto",
      "🎮 \"Every race is a game. Play to win.\" - Game Bot Philosophy",
      "🔪 \"Built for destruction, racing for dominance.\" - Murder Bot Creed",
      "🌍 \"The old world died. We race through its bones.\" - Wasteland Saying",
      "🔧 \"A well-maintained bot is a dangerous bot.\" - Garage Master Wisdom",
      "🏁 \"The Silent Klan sees all. They control the races.\" - Delta City Rumor",
      "⚙️ \"Scrap today, champion tomorrow.\" - Junker's Hope",
      "🎯 \"Precision beats chaos. Usually.\" - Master Protocol #47",
    ];

    // Return a quote based on some pseudo-random selection
    quotes[0]; // For now, return first one. Could add randomization later
  };

  public func cancelUpgrade(botName : Text, upgradeType : Text, refundInfo : Text) : Text {
    "🛑 **UPGRADE CANCELLED**\n\n" #
    "**" # botName # "** has aborted the " # upgradeType # " upgrade session.\n\n" #
    "⏱️ All progress lost - the wasteland doesn't forgive hesitation.\n" #
    "💰 " # refundInfo # "\n\n" #
    "Your bot is ready for other operations. Time wasted, lesson learned.";
  };
};
