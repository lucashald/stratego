#!/usr/bin/env python3
"""Standalone melee-resolution modeler.

Simulates a single isolated clash between two formations, many times, and
reports win/damage stats. Decoupled from the Godot engine and the bot AI on
purpose - this exists to compare resolution *rules* in a vacuum, without the
positioning/initiative confounds a real game or bot-vs-bot batch run carries.

Each rule is a plain function: (attacker, defender, rng) -> ClashResult.
Add new rules to RULES and rerun; nothing else needs to change.
"""

import argparse
import random
from dataclasses import dataclass, replace
from itertools import product

# --- Unit stats, mirrored from scripts/stratego_game.gd's TYPE_INFO / ARMOR_BY_WEIGHT ---

WEIGHTS = ["light", "medium", "heavy"]
STRENGTH_BY_WEIGHT = {"light": 6, "medium": 7, "heavy": 8}
ARMOR_BY_WEIGHT = {"light": 0, "medium": 1, "heavy": 2}
ROLE_BONUS = 3


@dataclass(frozen=True)
class Unit:
    label: str
    role: str  # "cavalry" or "infantry"
    weight: str
    strength: int
    armor: int


def make_unit(role: str, weight: str, strength: int | None = None) -> Unit:
    """strength defaults to the weight-tier table for convenience, but pass it
    explicitly to decouple the two - weight should only ever set armor (and,
    in the real game, movement), strength is its own independent dial."""
    return Unit(
        label=f"{weight[0].upper()}{role[0].upper()}" + ("" if strength is None else f"{strength}"),
        role=role,
        weight=weight,
        strength=STRENGTH_BY_WEIGHT[weight] if strength is None else strength,
        armor=ARMOR_BY_WEIGHT[weight],
    )


@dataclass
class ClashResult:
    winner: str  # "attacker", "defender", or "tie"
    attacker_damage: int
    defender_damage: int


# --- Rules ---

def rule_current(attacker: Unit, defender: Unit, rng: random.Random) -> ClashResult:
    """Mirrors _resolve_battle exactly for the 1v1 case: capped d10 + role
    bonus, unique highest score wins, loser takes (winner's score - own
    armor, doubled for the winner's own armor on their own damage taken) plus
    a flat +1 if the opponent rolled a natural 10."""
    a_roll = rng.randint(1, 10)
    d_roll = rng.randint(1, 10)
    a_capped = min(a_roll, attacker.strength)
    d_capped = min(d_roll, defender.strength)
    a_bonus = ROLE_BONUS if attacker.role == "cavalry" else 0
    d_bonus = ROLE_BONUS if defender.role == "infantry" else 0
    a_score = a_capped + a_bonus
    d_score = d_capped + d_bonus

    if a_score > d_score:
        winner = "attacker"
    elif d_score > a_score:
        winner = "defender"
    else:
        winner = "tie"

    a_eff_armor = attacker.armor * (2 if winner == "attacker" else 1)
    d_eff_armor = defender.armor * (2 if winner == "defender" else 1)
    a_damage = max(0, d_score - a_eff_armor) + (1 if d_roll == 10 else 0)
    d_damage = max(0, a_score - d_eff_armor) + (1 if a_roll == 10 else 0)

    if winner == "tie":
        a_damage = 0
        d_damage = 0

    return ClashResult(winner, a_damage, d_damage)


def rule_d6_strength_lossgap(attacker: Unit, defender: Unit, rng: random.Random) -> ClashResult:
    """1d6 + strength (uncapped, additive) + role bonus. Natural 6 is a crit,
    +1 flat damage. Only the loser takes damage, equal to the score gap; the
    winner takes nothing. A tie still bounces with no damage either way."""
    a_roll = rng.randint(1, 6)
    d_roll = rng.randint(1, 6)
    a_bonus = ROLE_BONUS if attacker.role == "cavalry" else 0
    d_bonus = ROLE_BONUS if defender.role == "infantry" else 0
    a_score = a_roll + attacker.strength + a_bonus
    d_score = d_roll + defender.strength + d_bonus

    if a_score > d_score:
        gap = a_score - d_score
        crit = 1 if a_roll == 6 else 0
        return ClashResult("attacker", 0, gap + crit)
    if d_score > a_score:
        gap = d_score - a_score
        crit = 1 if d_roll == 6 else 0
        return ClashResult("defender", gap + crit, 0)
    return ClashResult("tie", 0, 0)


def rule_d6_strength_rawdie(attacker: Unit, defender: Unit, rng: random.Random) -> ClashResult:
    """Same winner determination as d6str_lossgap: 1d6 + strength + role bonus,
    higher score wins. Damage is no longer the score gap - it's the *winning*
    side's raw die roll (crit +1 on a natural 6), reduced by the target's own
    armor. Only the loser takes damage on a decisive result, same as before.
    On a tie, both sides take damage from the other side's raw roll (also
    armor-reduced), instead of nothing - so armor matters every fight, not
    just when you lose, and ties stop being free."""
    a_roll = rng.randint(1, 6)
    d_roll = rng.randint(1, 6)
    a_bonus = ROLE_BONUS if attacker.role == "cavalry" else 0
    d_bonus = ROLE_BONUS if defender.role == "infantry" else 0
    a_score = a_roll + attacker.strength + a_bonus
    d_score = d_roll + defender.strength + d_bonus
    a_crit = 1 if a_roll == 6 else 0
    d_crit = 1 if d_roll == 6 else 0

    if a_score > d_score:
        d_damage = max(0, a_roll - defender.armor) + a_crit
        return ClashResult("attacker", 0, d_damage)
    if d_score > a_score:
        a_damage = max(0, d_roll - attacker.armor) + d_crit
        return ClashResult("defender", a_damage, 0)
    a_damage = max(0, d_roll - attacker.armor) + d_crit
    d_damage = max(0, a_roll - defender.armor) + a_crit
    return ClashResult("tie", a_damage, d_damage)


def _roll_side(has_bonus: bool, rng: random.Random) -> tuple[int, int]:
    """Returns (chosen_die, crit_count). The bonus role rolls 2d6 and keeps
    the higher die, with each individual 6 counting as a crit (so double
    sixes crit for +2, not +1). Everyone else rolls a plain 1d6."""
    if not has_bonus:
        roll = rng.randint(1, 6)
        return roll, (1 if roll == 6 else 0)
    d1 = rng.randint(1, 6)
    d2 = rng.randint(1, 6)
    crits = (1 if d1 == 6 else 0) + (1 if d2 == 6 else 0)
    return max(d1, d2), crits


def rule_2d6_role_rawdie(attacker: Unit, defender: Unit, rng: random.Random) -> ClashResult:
    """Replaces the flat +3 role bonus with a dice mechanic: the role that
    used to get the bonus (Cavalry attacking, Infantry defending) instead
    rolls 2d6 and keeps the higher die, everyone else rolls 1d6. Score is
    just roll + strength - no separate bonus term. Every 6 rolled (both dice,
    if 2d6) is a crit worth +1 damage. Damage otherwise follows d6str_rawdie:
    only the loser takes damage on a decisive result (the winner's chosen die
    minus the loser's armor, plus crits); a tie deals reciprocal damage to
    both sides the same way."""
    a_bonus = attacker.role == "cavalry"
    d_bonus = defender.role == "infantry"
    a_roll, a_crit = _roll_side(a_bonus, rng)
    d_roll, d_crit = _roll_side(d_bonus, rng)
    a_score = a_roll + attacker.strength
    d_score = d_roll + defender.strength

    if a_score > d_score:
        d_damage = max(0, a_roll - defender.armor) + a_crit
        return ClashResult("attacker", 0, d_damage)
    if d_score > a_score:
        a_damage = max(0, d_roll - attacker.armor) + d_crit
        return ClashResult("defender", a_damage, 0)
    a_damage = max(0, d_roll - attacker.armor) + d_crit
    d_damage = max(0, a_roll - defender.armor) + a_crit
    return ClashResult("tie", a_damage, d_damage)


def rule_2d6_role_rawdie_chip(attacker: Unit, defender: Unit, rng: random.Random) -> ClashResult:
    """Same as 2d6role_rawdie, but a loser's own crits (6s they rolled, even
    though they still lost outright) chip the winner for +1 damage each,
    unmitigated by armor - a lucky roll on the losing side still lands
    something, instead of a clean loss doing zero damage to the winner."""
    a_bonus = attacker.role == "cavalry"
    d_bonus = defender.role == "infantry"
    a_roll, a_crit = _roll_side(a_bonus, rng)
    d_roll, d_crit = _roll_side(d_bonus, rng)
    a_score = a_roll + attacker.strength
    d_score = d_roll + defender.strength

    if a_score > d_score:
        d_damage = max(0, a_roll - defender.armor) + a_crit
        return ClashResult("attacker", d_crit, d_damage)
    if d_score > a_score:
        a_damage = max(0, d_roll - attacker.armor) + d_crit
        return ClashResult("defender", a_damage, a_crit)
    a_damage = max(0, d_roll - attacker.armor) + d_crit
    d_damage = max(0, a_roll - defender.armor) + a_crit
    return ClashResult("tie", a_damage, d_damage)


def rule_marginmax(attacker: Unit, defender: Unit, rng: random.Random) -> ClashResult:
    """Same 2d6role scoring as 2d6role_rawdie. Damage matches the ranged
    model's "margin" flavor while fixing what pure margin breaks: decisive
    damage is max(margin, winner's raw die) - loser.armor + winner's crits,
    so a narrow win still guarantees at least what raw-die damage would have
    done, and a blowout margin can exceed it. A tie has margin 0, so it falls
    straight through to the raw-die floor on both sides - ties are never a
    no-op here."""
    a_bonus = attacker.role == "cavalry"
    d_bonus = defender.role == "infantry"
    a_roll, a_crit = _roll_side(a_bonus, rng)
    d_roll, d_crit = _roll_side(d_bonus, rng)
    a_score = a_roll + attacker.strength
    d_score = d_roll + defender.strength

    if a_score > d_score:
        margin = a_score - d_score
        d_damage = max(margin, a_roll) - defender.armor
        return ClashResult("attacker", 0, max(0, d_damage) + a_crit)
    if d_score > a_score:
        margin = d_score - a_score
        a_damage = max(margin, d_roll) - attacker.armor
        return ClashResult("defender", max(0, a_damage) + d_crit, 0)
    a_damage = max(0, d_roll - attacker.armor) + d_crit
    d_damage = max(0, a_roll - defender.armor) + a_crit
    return ClashResult("tie", a_damage, d_damage)


def rule_marginfallback(attacker: Unit, defender: Unit, rng: random.Random) -> ClashResult:
    """Same 2d6role scoring. Decisive damage is *pure* margin - loser.armor +
    winner's crits, matching the ranged margin mechanic exactly with no raw-
    die blend. Only a tie (margin always 0) falls back to raw-die damage on
    both sides, purely to avoid the free-round problem - every other result
    is margin, full stop."""
    a_bonus = attacker.role == "cavalry"
    d_bonus = defender.role == "infantry"
    a_roll, a_crit = _roll_side(a_bonus, rng)
    d_roll, d_crit = _roll_side(d_bonus, rng)
    a_score = a_roll + attacker.strength
    d_score = d_roll + defender.strength

    if a_score > d_score:
        margin = a_score - d_score
        return ClashResult("attacker", 0, max(0, margin - defender.armor) + a_crit)
    if d_score > a_score:
        margin = d_score - a_score
        return ClashResult("defender", max(0, margin - attacker.armor) + d_crit, 0)
    a_damage = max(0, d_roll - attacker.armor) + d_crit
    d_damage = max(0, a_roll - defender.armor) + a_crit
    return ClashResult("tie", a_damage, d_damage)


WEIGHT_SCORE_BONUS = ARMOR_BY_WEIGHT  # 0/1/2 for light/medium/heavy - happens to be the same table


def rule_weightscore_marginmax(attacker: Unit, defender: Unit, rng: random.Random) -> ClashResult:
    """A different scoring formula entirely, dropping strength from the score
    altogether: score = 1d6 + weight bonus (0/1/2 for light/medium/heavy) + 1
    for Cavalry attacking + 1 for Infantry defending. Weight now buys offense
    as well as armor, so a Heavy formation hits harder, not just tougher -
    strength stops being the only thing that makes a unit dangerous. Damage
    uses the marginmax approach (max(margin, raw die) - armor + crit) since
    that was the most complete of the two damage options; ties still fall
    back to raw die."""
    a_roll = rng.randint(1, 6)
    d_roll = rng.randint(1, 6)
    a_crit = 1 if a_roll == 6 else 0
    d_crit = 1 if d_roll == 6 else 0
    a_score = a_roll + WEIGHT_SCORE_BONUS[attacker.weight] + (1 if attacker.role == "cavalry" else 0)
    d_score = d_roll + WEIGHT_SCORE_BONUS[defender.weight] + (1 if defender.role == "infantry" else 0)

    if a_score > d_score:
        margin = a_score - d_score
        return ClashResult("attacker", 0, max(0, max(margin, a_roll) - defender.armor) + a_crit)
    if d_score > a_score:
        margin = d_score - a_score
        return ClashResult("defender", max(0, max(margin, d_roll) - attacker.armor) + d_crit, 0)
    a_damage = max(0, d_roll - attacker.armor) + d_crit
    d_damage = max(0, a_roll - defender.armor) + a_crit
    return ClashResult("tie", a_damage, d_damage)


WEIGHT_EXTRA_DICE = {"light": 0, "medium": 1, "heavy": 2}


def _roll_pool(weight: str, has_role_bonus: bool, rng: random.Random) -> tuple[int, int]:
    """1 base d6, +1 extra for medium, +2 extra for heavy, +1 more if this
    side has the charge/defend role bonus - all pooled together, keep the
    single highest die. Every 6 anywhere in the pool is a crit."""
    pool_size = 1 + WEIGHT_EXTRA_DICE[weight] + (1 if has_role_bonus else 0)
    dice = [rng.randint(1, 6) for _ in range(pool_size)]
    return max(dice), sum(1 for d in dice if d == 6)


def rule_weightdice_str_marginmax(attacker: Unit, defender: Unit, rng: random.Random) -> ClashResult:
    """Score is still roll + strength (strength stays in, unlike weightscore).
    What changes is how the roll is generated: everyone rolls a pool of d6s -
    1 base, +1 for Medium, +2 for Heavy, +1 more if this side has the charge
    (Cavalry attacking) or defend (Infantry defending) bonus - and keeps the
    single highest die from the whole pool. So weight now buys a bigger,
    more-reliable die (not a flat score bonus, and not touching strength),
    while strength keeps being the direct damage/score driver as before.
    Damage uses the marginmax approach: max(margin, winner's die) -
    loser.armor + crits, ties fall back to raw die on both sides."""
    a_bonus = attacker.role == "cavalry"
    d_bonus = defender.role == "infantry"
    a_roll, a_crit = _roll_pool(attacker.weight, a_bonus, rng)
    d_roll, d_crit = _roll_pool(defender.weight, d_bonus, rng)
    a_score = a_roll + attacker.strength
    d_score = d_roll + defender.strength

    if a_score > d_score:
        margin = a_score - d_score
        return ClashResult("attacker", 0, max(0, max(margin, a_roll) - defender.armor) + a_crit)
    if d_score > a_score:
        margin = d_score - a_score
        return ClashResult("defender", max(0, max(margin, d_roll) - attacker.armor) + d_crit, 0)
    a_damage = max(0, d_roll - attacker.armor) + d_crit
    d_damage = max(0, a_roll - defender.armor) + a_crit
    return ClashResult("tie", a_damage, d_damage)


WEIGHT_RANK = {"light": 0, "medium": 1, "heavy": 2}


def rule_comparative_dice_marginmax(attacker: Unit, defender: Unit, rng: random.Random) -> ClashResult:
    """1 base d6 each. +1 die if this side is the heavier of the two (not a
    flat per-weight scale like the last version - only matters relative to
    the opponent, so two Heavies fighting each other get no bonus from it at
    all). +1 die if this side has strictly higher strength than the opponent,
    same comparative logic. +1 die for attacking Cavalry, +1 for defending
    Infantry, as always. Score is still highest-die + strength. Damage is
    marginmax, same crit-per-6 rule as everything else."""
    a_extra = (
        (1 if WEIGHT_RANK[attacker.weight] > WEIGHT_RANK[defender.weight] else 0)
        + (1 if attacker.strength > defender.strength else 0)
        + (1 if attacker.role == "cavalry" else 0)
    )
    d_extra = (
        (1 if WEIGHT_RANK[defender.weight] > WEIGHT_RANK[attacker.weight] else 0)
        + (1 if defender.strength > attacker.strength else 0)
        + (1 if defender.role == "infantry" else 0)
    )
    a_dice = [rng.randint(1, 6) for _ in range(1 + a_extra)]
    d_dice = [rng.randint(1, 6) for _ in range(1 + d_extra)]
    a_roll, a_crit = max(a_dice), sum(1 for d in a_dice if d == 6)
    d_roll, d_crit = max(d_dice), sum(1 for d in d_dice if d == 6)
    a_score = a_roll + attacker.strength
    d_score = d_roll + defender.strength

    if a_score > d_score:
        margin = a_score - d_score
        return ClashResult("attacker", 0, max(0, max(margin, a_roll) - defender.armor) + a_crit)
    if d_score > a_score:
        margin = d_score - a_score
        return ClashResult("defender", max(0, max(margin, d_roll) - attacker.armor) + d_crit, 0)
    a_damage = max(0, d_roll - attacker.armor) + d_crit
    d_damage = max(0, a_roll - defender.armor) + a_crit
    return ClashResult("tie", a_damage, d_damage)


RULES = {
    "current": rule_current,
    "d6str_lossgap": rule_d6_strength_lossgap,
    "d6str_rawdie": rule_d6_strength_rawdie,
    "2d6role_rawdie": rule_2d6_role_rawdie,
    "2d6role_rawdie_chip": rule_2d6_role_rawdie_chip,
    "marginmax": rule_marginmax,
    "marginfallback": rule_marginfallback,
    "weightscore_marginmax": rule_weightscore_marginmax,
    "weightdice_str_marginmax": rule_weightdice_str_marginmax,
    "comparative_dice_marginmax": rule_comparative_dice_marginmax,
}


# --- Ranged rules: one-sided, the target never rolls ---

@dataclass
class RangedResult:
    hit: bool
    damage: int


def ranged_rule_v1(archer: Unit, target: Unit, rng: random.Random) -> RangedResult:
    """Archer rolls 1d6 + strength against the target's bare strength (no die
    for the target - it doesn't get to contest a shot the way melee lets a
    defender fight back). If the archer's score beats the target's strength,
    it's a hit for (die roll - target armor), floored at 0. No crit rule
    specified yet - a miss is a clean 0, not even a graze."""
    roll = rng.randint(1, 6)
    score = roll + archer.strength
    if score > target.strength:
        return RangedResult(True, max(0, roll - target.armor))
    return RangedResult(False, 0)


def ranged_rule_v2_margin(archer: Unit, target: Unit, rng: random.Random) -> RangedResult:
    """Same hit test as archer_v1 (1d6 + strength vs target's bare strength),
    but damage is the raw die *plus* the margin the shot beat the target's
    strength by, then armor-reduced: damage = roll + (score - target.strength)
    - target.armor, floored at 0. A bare hit does about what v1 did; a big
    strength gap or a lucky high roll compounds into a much bigger hit,
    including one-shotting a much weaker target outright."""
    roll = rng.randint(1, 6)
    score = roll + archer.strength
    if score <= target.strength:
        return RangedResult(False, 0)
    margin = score - target.strength
    return RangedResult(True, max(0, roll + margin - target.armor))


def ranged_rule_v3_contest(archer: Unit, target: Unit, rng: random.Random) -> RangedResult:
    """The target now rolls too, instead of just having a bare strength
    threshold: archer rolls 2d6 keep-highest + strength (the "aim" advantage,
    same shape as a melee charge bonus), target rolls a plain 1d6 + strength.
    A hit only happens if the archer's score is strictly higher. Damage is
    just the margin - target.armor (not margin + raw die, which was double-
    counting the same roll twice), plus +1 per 6 the archer rolled (crit,
    both dice count if both are 6). The target's own roll only ever decides
    whether it dodges the shot entirely - it never shoots back."""
    a1 = rng.randint(1, 6)
    a2 = rng.randint(1, 6)
    a_roll = max(a1, a2)
    a_crit = (1 if a1 == 6 else 0) + (1 if a2 == 6 else 0)
    d_roll = rng.randint(1, 6)
    a_score = a_roll + archer.strength
    d_score = d_roll + target.strength
    if a_score > d_score:
        margin = a_score - d_score
        return RangedResult(True, max(0, margin - target.armor) + a_crit)
    return RangedResult(False, 0)


def ranged_rule_v4_armordice(archer: Unit, target: Unit, rng: random.Random) -> RangedResult:
    """Archer still rolls 2d6 keep-highest + strength. The target's defensive
    roll now scales with its own armor instead of being a flat 1d6: it rolls
    `armor` d6 and keeps the highest (0 armor = 0 dice = no roll at all, its
    score is bare strength). Hit still requires the archer's score to beat
    the target's. Damage on a hit is margin - target.armor + net crit, same
    shape as v3. New: a 6 on either side is a crit, but a defender's 6
    cancels an attacker's 6 one-for-one (net_crit = max(0, archer_crits -
    defender_crits)). And a net crit still chips through for +1 even on an
    outright miss - a lucky arrow still lands something even against a
    hopeless mismatch, unless the defender's own 6 cancels it."""
    a1 = rng.randint(1, 6)
    a2 = rng.randint(1, 6)
    a_roll = max(a1, a2)
    a_crits = (1 if a1 == 6 else 0) + (1 if a2 == 6 else 0)

    d_dice = [rng.randint(1, 6) for _ in range(target.armor)]
    d_roll = max(d_dice) if d_dice else 0
    d_crits = sum(1 for die in d_dice if die == 6)

    a_score = a_roll + archer.strength
    d_score = d_roll + target.strength
    net_crit = max(0, a_crits - d_crits)

    if a_score > d_score:
        margin = a_score - d_score
        return RangedResult(True, max(0, margin - target.armor) + net_crit)
    return RangedResult(net_crit > 0, net_crit)


RANGED_RULES = {
    "archer_v1": ranged_rule_v1,
    "archer_v2_margin": ranged_rule_v2_margin,
    "archer_v3_contest": ranged_rule_v3_contest,
    "archer_v4_armordice": ranged_rule_v4_armordice,
}


# --- Simulation ---

def simulate(attacker: Unit, defender: Unit, rule, trials: int, rng: random.Random) -> dict:
    wins_a = wins_d = ties = 0
    dmg_a_total = dmg_d_total = 0
    for _ in range(trials):
        result = rule(attacker, defender, rng)
        if result.winner == "attacker":
            wins_a += 1
        elif result.winner == "defender":
            wins_d += 1
        else:
            ties += 1
        dmg_a_total += result.attacker_damage
        dmg_d_total += result.defender_damage
    return {
        "win_a": wins_a / trials,
        "win_d": wins_d / trials,
        "tie": ties / trials,
        "avg_dmg_a": dmg_a_total / trials,
        "avg_dmg_d": dmg_d_total / trials,
    }


def print_grid(attackers, defenders, rule_name: str, trials: int, seed: int) -> None:
    rule = RULES[rule_name]
    rng = random.Random(seed)
    print(f"\n=== rule: {rule_name}  ({trials} trials/matchup, seed={seed}) ===")
    col_width = 30
    header = "attacker \\ defender".ljust(12) + "".join(d.label.center(col_width) for d in defenders)
    print(header)
    for a in attackers:
        row = a.label.ljust(12)
        for d in defenders:
            stats = simulate(a, d, rule, trials, rng)
            cell = (f"A{stats['win_a']*100:3.0f} D{stats['win_d']*100:3.0f} T{stats['tie']*100:3.0f}"
                    f" dA{stats['avg_dmg_a']:.1f} dD{stats['avg_dmg_d']:.1f}")
            row += " | " + cell.ljust(col_width - 3)
        print(row)


def simulate_ranged(archer: Unit, target: Unit, rule, trials: int, rng: random.Random) -> dict:
    hits = 0
    dmg_total = 0
    for _ in range(trials):
        result = rule(archer, target, rng)
        if result.hit:
            hits += 1
        dmg_total += result.damage
    return {"hit_rate": hits / trials, "avg_dmg": dmg_total / trials}


def print_ranged_grid(archers, targets, rule_name: str, trials: int, seed: int) -> None:
    rule = RANGED_RULES[rule_name]
    rng = random.Random(seed)
    print(f"\n=== ranged rule: {rule_name}  ({trials} trials/matchup, seed={seed}) ===")
    col_width = 16
    header = "archer \\ target".ljust(12) + "".join(t.label.center(col_width) for t in targets)
    print(header)
    for a in archers:
        row = a.label.ljust(12)
        for t in targets:
            stats = simulate_ranged(a, t, rule, trials, rng)
            cell = f"hit{stats['hit_rate']*100:3.0f}% dmg{stats['avg_dmg']:.1f}"
            row += " | " + cell.ljust(col_width - 3)
        print(row)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", default="melee", choices=["melee", "ranged"])
    parser.add_argument("--rule", default=None)
    parser.add_argument("--trials", type=int, default=20000)
    parser.add_argument("--seed", type=int, default=1)
    args = parser.parse_args()

    cavalry = [make_unit("cavalry", w) for w in WEIGHTS]
    infantry = [make_unit("infantry", w) for w in WEIGHTS]

    if args.mode == "ranged":
        rule_name = args.rule or "archer_v1"
        archers = [make_unit("archer", w) for w in WEIGHTS]
        print_ranged_grid(archers, infantry, rule_name, args.trials, args.seed)
        print("\n(archer strength/armor by weight tier vs a stationary target's weight tier; role doesn't affect this rule)")
        return

    rule_name = args.rule or "current"
    print_grid(cavalry, infantry, rule_name, args.trials, args.seed)
    print("\n(attacker = row, charging into defender = column; A/D% are win rates, dmg is average damage dealt to that side)")

    print_grid(infantry, cavalry, rule_name, args.trials, args.seed)
    print("\n(same grid with roles swapped: infantry attacking cavalry)")

    print_grid(cavalry, cavalry, rule_name, args.trials, args.seed)
    print("\n(cavalry attacking cavalry - neither side has the defend bonus, only the attacker's charge bonus applies)")


if __name__ == "__main__":
    main()
