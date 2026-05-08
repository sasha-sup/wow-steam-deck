#!/usr/bin/env bash
# Step 11 (optional) — apply a generous rate preset to worldserver.conf so
# leveling, drops, reputation and skills feel "kayf" on a single-player
# server. Backs up the conf first; restart worldserver after running.
#
# Re-running is safe: every line is rewritten with the same target value.
#
# Tweak the values below if you want a different feel. x5 XP / x3 talents
# is a classic private-server preset; epic/legendary boosts are biased
# toward making rare drops actually drop on a small population.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

CONF_PATH="$WOW_ROOT/configs/worldserver.conf"

log "Backing up $CONF_PATH ..."
deck "cp -n \"$CONF_PATH\" \"$CONF_PATH.bak.\$(date +%s)\" || true"

log "Applying rate preset to $CONF_PATH ..."
deck "
sed -i \\
  -e 's/^Rate\\.XP\\.Kill\\s*=.*/Rate.XP.Kill      = 5/' \\
  -e 's/^Rate\\.XP\\.Quest\\s*=.*/Rate.XP.Quest     = 5/' \\
  -e 's/^Rate\\.XP\\.Quest\\.DF\\s*=.*/Rate.XP.Quest.DF  = 5/' \\
  -e 's/^Rate\\.XP\\.Explore\\s*=.*/Rate.XP.Explore   = 5/' \\
  -e 's/^Rate\\.XP\\.Pet\\s*=.*/Rate.XP.Pet       = 5/' \\
  -e 's/^Rate\\.XP\\.BattlegroundKillAV\\s*=.*/Rate.XP.BattlegroundKillAV   = 5/' \\
  -e 's/^Rate\\.XP\\.BattlegroundKillWSG\\s*=.*/Rate.XP.BattlegroundKillWSG  = 5/' \\
  -e 's/^Rate\\.XP\\.BattlegroundKillAB\\s*=.*/Rate.XP.BattlegroundKillAB   = 5/' \\
  -e 's/^Rate\\.XP\\.BattlegroundKillEOTS\\s*=.*/Rate.XP.BattlegroundKillEOTS = 5/' \\
  -e 's/^Rate\\.XP\\.BattlegroundKillSOTA\\s*=.*/Rate.XP.BattlegroundKillSOTA = 5/' \\
  -e 's/^Rate\\.XP\\.BattlegroundKillIC\\s*=.*/Rate.XP.BattlegroundKillIC   = 5/' \\
  -e 's/^Rate\\.XP\\.BattlegroundBonus\\s*=.*/Rate.XP.BattlegroundBonus = 5/' \\
  -e 's/^Rate\\.Talent\\s*=.*/Rate.Talent = 3/' \\
  -e 's/^Rate\\.Talent\\.Pet\\s*=.*/Rate.Talent.Pet = 3/' \\
  -e 's/^Rate\\.Reputation\\.Gain\\s*=.*/Rate.Reputation.Gain = 5/' \\
  -e 's/^Rate\\.Reputation\\.LowLevel\\.Kill\\s*=.*/Rate.Reputation.LowLevel.Kill = 5/' \\
  -e 's/^Rate\\.Reputation\\.LowLevel\\.Quest\\s*=.*/Rate.Reputation.LowLevel.Quest = 5/' \\
  -e 's/^Rate\\.Reputation\\.Gain\\.WSG\\s*=.*/Rate.Reputation.Gain.WSG = 5/' \\
  -e 's/^Rate\\.Reputation\\.Gain\\.AB\\s*=.*/Rate.Reputation.Gain.AB = 5/' \\
  -e 's/^Rate\\.Reputation\\.Gain\\.AV\\s*=.*/Rate.Reputation.Gain.AV = 5/' \\
  -e 's/^Rate\\.Honor\\s*=.*/Rate.Honor = 5/' \\
  -e 's/^Rate\\.Drop\\.Money\\s*=.*/Rate.Drop.Money                 = 5/' \\
  -e 's/^Rate\\.Drop\\.Item\\.Poor\\s*=.*/Rate.Drop.Item.Poor             = 5/' \\
  -e 's/^Rate\\.Drop\\.Item\\.Normal\\s*=.*/Rate.Drop.Item.Normal           = 5/' \\
  -e 's/^Rate\\.Drop\\.Item\\.Uncommon\\s*=.*/Rate.Drop.Item.Uncommon         = 5/' \\
  -e 's/^Rate\\.Drop\\.Item\\.Rare\\s*=.*/Rate.Drop.Item.Rare             = 5/' \\
  -e 's/^Rate\\.Drop\\.Item\\.Epic\\s*=.*/Rate.Drop.Item.Epic             = 5/' \\
  -e 's/^Rate\\.Drop\\.Item\\.Legendary\\s*=.*/Rate.Drop.Item.Legendary        = 10/' \\
  -e 's/^Rate\\.Drop\\.Item\\.Artifact\\s*=.*/Rate.Drop.Item.Artifact         = 10/' \\
  -e 's/^Rate\\.Drop\\.Item\\.Referenced\\s*=.*/Rate.Drop.Item.Referenced       = 5/' \\
  -e 's/^Rate\\.Drop\\.Item\\.ReferencedAmount\\s*=.*/Rate.Drop.Item.ReferencedAmount = 3/' \\
  -e 's/^Rate\\.Drop\\.Item\\.GroupAmount\\s*=.*/Rate.Drop.Item.GroupAmount = 3/' \\
  -e 's/^Rate\\.Skill\\.Discovery\\s*=.*/Rate.Skill.Discovery = 5/' \\
  -e 's/^SkillGain\\.Crafting\\s*=.*/SkillGain.Crafting  = 5/' \\
  -e 's/^SkillGain\\.Defense\\s*=.*/SkillGain.Defense   = 5/' \\
  -e 's/^SkillGain\\.Gathering\\s*=.*/SkillGain.Gathering = 5/' \\
  -e 's/^SkillGain\\.Weapon\\s*=.*/SkillGain.Weapon    = 5/' \\
  -e 's/^SkillChance\\.Green\\s*=.*/SkillChance.Green  = 75/' \\
  -e 's/^SkillChance\\.Grey\\s*=.*/SkillChance.Grey   = 25/' \\
  -e 's/^SkillChance\\.MiningSteps\\s*=.*/SkillChance.MiningSteps   = 1/' \\
  -e 's/^SkillChance\\.SkinningSteps\\s*=.*/SkillChance.SkinningSteps = 1/' \\
  -e 's/^SkillChance\\.Prospecting\\s*=.*/SkillChance.Prospecting = 1/' \\
  -e 's/^SkillChance\\.Milling\\s*=.*/SkillChance.Milling = 1/' \\
  -e 's/^MaxGroupXPDistance\\s*=.*/MaxGroupXPDistance = 250/' \\
  -e 's/^MailDeliveryDelay\\s*=.*/MailDeliveryDelay = 60/' \\
  -e 's/^Rate\\.Auction\\.Deposit\\s*=.*/Rate.Auction.Deposit = 0/' \\
  -e 's/^Rate\\.Auction\\.Cut\\s*=.*/Rate.Auction.Cut     = 0/' \\
  -e 's/^Rate\\.InstanceResetTime\\s*=.*/Rate.InstanceResetTime = 0.5/' \\
  -e 's/^Rate\\.Corpse\\.Decay\\.Looted\\s*=.*/Rate.Corpse.Decay.Looted = 1/' \\
  -e 's/^Rate\\.Rest\\.InGame\\s*=.*/Rate.Rest.InGame                 = 3/' \\
  -e 's/^InstantLogout\\s*=.*/InstantLogout = 3/' \\
  -e 's/^SkipCinematics\\s*=.*/SkipCinematics = 2/' \\
  -e 's/^StartPlayerMoney\\s*=.*/StartPlayerMoney = 1000000/' \\
  -e 's/^Quests\\.IgnoreAutoAccept\\s*=.*/Quests.IgnoreAutoAccept = 1/' \\
  -e 's/^Quests\\.IgnoreAutoComplete\\s*=.*/Quests.IgnoreAutoComplete = 1/' \\
  \"$CONF_PATH\"
"

log "Restarting worldserver to pick up the new rates..."
deck "podman ps --format '{{.Names}}' | grep -q '^ac-worldserver\$' && podman restart ac-worldserver || true"

log "Step 11 complete. Inspect: grep -nE '^Rate\\.' $CONF_PATH"
