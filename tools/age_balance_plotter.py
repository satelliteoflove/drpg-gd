import sys

try:
    import matplotlib.pyplot as plt
    import matplotlib.gridspec as gridspec
    import numpy as np
except ImportError:
    print("Missing dependencies. Run with:")
    print("  uv run --with matplotlib --with numpy python3 tools/age_balance_plotter.py")
    sys.exit(1)


RACE_DATA = {
    "Human":   {"start_age": 18,  "prime_start": 22, "prime_end": 45, "decline_end": 65,  "max_age": 80},
    "Elf":     {"start_age": 75,  "prime_start": 120, "prime_end": 400, "decline_end": 550, "max_age": 650},
    "Dwarf":   {"start_age": 50,  "prime_start": 70, "prime_end": 180, "decline_end": 250, "max_age": 300},
    "Gnome":   {"start_age": 60,  "prime_start": 80, "prime_end": 200, "decline_end": 280, "max_age": 350},
    "Hobbit":  {"start_age": 30,  "prime_start": 40, "prime_end": 80,  "decline_end": 100, "max_age": 120},
    "Faerie":  {"start_age": 25,  "prime_start": 40, "prime_end": 150, "decline_end": 200, "max_age": 250},
    "Lizman":  {"start_age": 20,  "prime_start": 25, "prime_end": 40,  "decline_end": 55,  "max_age": 65},
    "Dracon":  {"start_age": 40,  "prime_start": 55, "prime_end": 120, "decline_end": 160, "max_age": 200},
    "Rawulf":  {"start_age": 16,  "prime_start": 20, "prime_end": 35,  "decline_end": 45,  "max_age": 55},
    "Mook":    {"start_age": 15,  "prime_start": 20, "prime_end": 35,  "decline_end": 45,  "max_age": 55},
    "Felpurr": {"start_age": 22,  "prime_start": 28, "prime_end": 45,  "decline_end": 60,  "max_age": 70},
}

XP_MODIFIERS_CURRENT = {
    "Human":   {"Fighter": 1.0, "Mage": 1.0, "Priest": 1.0, "Thief": 1.0, "Alchemist": 1.0, "Bishop": 1.2, "Bard": 1.1, "Ranger": 1.1, "Psionic": 1.1, "Valkyrie": 1.2, "Samurai": 1.3, "Lord": 1.3, "Monk": 1.3, "Ninja": 1.4},
    "Elf":     {"Fighter": 1.1, "Mage": 0.9, "Priest": 0.9, "Thief": 1.1, "Alchemist": 1.0, "Bishop": 1.1, "Bard": 1.0, "Ranger": 1.0, "Psionic": 1.0, "Valkyrie": 1.3, "Samurai": 1.4, "Lord": 1.4, "Monk": 1.4, "Ninja": 1.5},
    "Dwarf":   {"Fighter": 0.9, "Mage": 1.3, "Priest": 1.0, "Thief": 1.2, "Alchemist": 1.1, "Bishop": 1.3, "Bard": 1.2, "Ranger": 1.2, "Psionic": 1.3, "Valkyrie": 1.3, "Samurai": 1.4, "Lord": 1.2, "Monk": 1.4, "Ninja": 1.5},
    "Gnome":   {"Fighter": 1.0, "Mage": 1.1, "Priest": 0.8, "Thief": 1.0, "Alchemist": 0.9, "Bishop": 1.0, "Bard": 1.1, "Ranger": 1.1, "Psionic": 1.0, "Valkyrie": 1.4, "Samurai": 1.5, "Lord": 1.4, "Monk": 1.3, "Ninja": 1.4},
    "Hobbit":  {"Fighter": 1.1, "Mage": 1.1, "Priest": 1.2, "Thief": 0.8, "Alchemist": 1.1, "Bishop": 1.3, "Bard": 1.0, "Ranger": 1.0, "Psionic": 1.2, "Valkyrie": 1.5, "Samurai": 1.5, "Lord": 1.5, "Monk": 1.4, "Ninja": 1.3},
    "Faerie":  {"Fighter": 1.4, "Mage": 0.8, "Priest": 1.2, "Thief": 0.9, "Alchemist": 1.0, "Bishop": 1.1, "Bard": 0.9, "Ranger": 1.0, "Psionic": 0.9, "Valkyrie": 1.4, "Samurai": 1.6, "Lord": 1.6, "Monk": 1.5, "Ninja": 1.3},
    "Lizman":  {"Fighter": 0.8, "Mage": 1.4, "Priest": 1.4, "Thief": 1.3, "Alchemist": 1.3, "Bishop": 1.5, "Bard": 1.4, "Ranger": 1.2, "Psionic": 1.4, "Valkyrie": 1.2, "Samurai": 1.3, "Lord": 1.3, "Monk": 1.3, "Ninja": 1.5},
    "Dracon":  {"Fighter": 0.9, "Mage": 1.2, "Priest": 1.3, "Thief": 1.1, "Alchemist": 1.2, "Bishop": 1.4, "Bard": 1.2, "Ranger": 1.1, "Psionic": 1.3, "Valkyrie": 1.3, "Samurai": 1.3, "Lord": 1.3, "Monk": 1.4, "Ninja": 1.5},
    "Rawulf":  {"Fighter": 1.1, "Mage": 1.3, "Priest": 0.9, "Thief": 1.1, "Alchemist": 1.0, "Bishop": 1.2, "Bard": 1.1, "Ranger": 1.0, "Psionic": 1.0, "Valkyrie": 1.4, "Samurai": 1.4, "Lord": 1.3, "Monk": 1.3, "Ninja": 1.4},
    "Mook":    {"Fighter": 1.0, "Mage": 1.0, "Priest": 1.3, "Thief": 1.1, "Alchemist": 1.1, "Bishop": 1.2, "Bard": 1.1, "Ranger": 1.1, "Psionic": 1.1, "Valkyrie": 1.3, "Samurai": 1.3, "Lord": 1.4, "Monk": 1.4, "Ninja": 1.4},
    "Felpurr": {"Fighter": 1.2, "Mage": 1.0, "Priest": 1.2, "Thief": 0.9, "Alchemist": 1.1, "Bishop": 1.3, "Bard": 1.0, "Ranger": 1.0, "Psionic": 1.1, "Valkyrie": 1.3, "Samurai": 1.4, "Lord": 1.5, "Monk": 1.3, "Ninja": 1.3},
}

PROPOSED_CHANGES = {
    "Lizman":  {"Fighter": 0.7},
    "Rawulf":  {"Priest": 0.7},
    "Felpurr": {"Thief": 0.7},
    "Mook_Monk":  {"Monk": 0.7},
    "Mook_Mage":  {"Mage": 0.7},
}

def build_proposed_modifiers(mook_option="Monk"):
    proposed = {}
    for race, mods in XP_MODIFIERS_CURRENT.items():
        proposed[race] = dict(mods)
    for race, changes in PROPOSED_CHANGES.items():
        if race.startswith("Mook_"):
            if race == f"Mook_{mook_option}":
                for cls, val in changes.items():
                    proposed["Mook"][cls] = val
        else:
            for cls, val in changes.items():
                proposed[race][cls] = val
    return proposed

XP_MODIFIERS = XP_MODIFIERS_CURRENT

BASE_XP_TABLE = [0, 1000, 2500, 5000, 9000, 15000, 25000, 40000, 60000, 90000,
                 135000, 200000, 280000, 380000, 500000, 650000, 830000, 1050000, 1300000, 1600000]

STAT_PEAK = 100.0
YOUTH_BONUS = 5.0

AVG_XP_PER_ENCOUNTER_BY_FLOOR = {
    1: 25, 2: 35, 3: 50, 4: 65, 5: 95, 6: 120, 7: 200,
    8: 300, 9: 450, 10: 650, 11: 900, 12: 1300, 13: 1800,
    14: 2500, 15: 3500, 16: 5000, 17: 7000, 18: 10000, 19: 14000, 20: 20000,
}

ENCOUNTERS_PER_YEAR = 100
YEARS_PER_FLOOR_CLEAR = 1.5
PARTY_SIZE = 6


def get_level_for_xp(total_xp, modifier):
    level = 1
    for i in range(len(BASE_XP_TABLE)):
        required = BASE_XP_TABLE[i] * modifier
        if total_xp >= required:
            level = i + 1
        else:
            break
    return min(level, 20)


def simulate_career(race_name, data, class_name, modifier):
    career_years = data["max_age"] - data["start_age"]
    cumulative_xp = 0.0
    current_floor = 1
    years_on_floor = 0.0
    year_data = []

    for year in range(career_years + 1):
        age = data["start_age"] + year
        level = get_level_for_xp(cumulative_xp, modifier)

        floor_xp = AVG_XP_PER_ENCOUNTER_BY_FLOOR.get(current_floor, 20000)
        xp_this_year = floor_xp * ENCOUNTERS_PER_YEAR / PARTY_SIZE
        cumulative_xp += xp_this_year

        years_on_floor += 1
        if years_on_floor >= YEARS_PER_FLOOR_CLEAR and current_floor < 20:
            current_floor += 1
            years_on_floor = 0

        year_data.append({
            "age": age,
            "level": get_level_for_xp(cumulative_xp, modifier),
            "cumulative_xp": cumulative_xp,
            "floor": current_floor,
            "xp_this_year": xp_this_year,
        })

    return year_data


def find_level_at_age(career_data, target_age):
    for entry in career_data:
        if entry["age"] >= target_age:
            return entry["level"]
    return career_data[-1]["level"] if career_data else 1


def find_age_at_level(career_data, target_level):
    for entry in career_data:
        if entry["level"] >= target_level:
            return entry["age"]
    return None


def compute_stat_curve(race_name, data):
    ages = list(range(data["start_age"], data["max_age"] + 1))
    stats = []
    for age in ages:
        if age < data["prime_start"]:
            progress = (age - data["start_age"]) / max(1, data["prime_start"] - data["start_age"])
            stat = (STAT_PEAK - YOUTH_BONUS) + YOUTH_BONUS * progress
        elif age <= data["prime_end"]:
            stat = STAT_PEAK
        elif age <= data["decline_end"]:
            progress = (age - data["prime_end"]) / max(1, data["decline_end"] - data["prime_end"])
            stat = STAT_PEAK * (1.0 - 0.4 * progress)
        else:
            progress = (age - data["decline_end"]) / max(1, data["max_age"] - data["decline_end"])
            stat = STAT_PEAK * 0.6 * (1.0 - 0.5 * progress)
        stats.append(stat)
    return ages, stats


def compute_death_chance(race_name, data):
    ages = list(range(data["start_age"], data["max_age"] + 1))
    chances = []
    for age in ages:
        if age <= data["decline_end"]:
            chances.append(0.0)
        else:
            progress = (age - data["decline_end"]) / max(1, data["max_age"] - data["decline_end"])
            chance = min(0.95, progress * progress * 0.8)
            chances.append(chance * 100)
    return ages, chances


def add_age_lines(ax, interval=5):
    for age in range(0, 700, interval):
        ax.axvline(x=age, color="gray", linestyle=":", alpha=0.15, linewidth=0.5)


def plot_all(output_path="tools/age_balance_charts.png"):
    fig = plt.figure(figsize=(24, 62))
    gs = gridspec.GridSpec(10, 1, hspace=0.35)

    colors = plt.cm.tab20(np.linspace(0, 1, len(RACE_DATA)))
    race_colors = {name: colors[i] for i, name in enumerate(RACE_DATA.keys())}
    race_names = list(RACE_DATA.keys())

    # find max age across all races for consistent x-axis on absolute-age charts
    max_age_all = max(d["max_age"] for d in RACE_DATA.values())

    # 1. stat curves (absolute age, with age lines)
    ax1 = fig.add_subplot(gs[0])
    ax1.set_title("Physical Stat Curve by Race (% of Peak)", fontsize=14, fontweight="bold")
    ax1.set_xlabel("Age (years)")
    ax1.set_ylabel("Stat %")
    ax1.set_ylim(0, 110)
    ax1.set_xlim(0, max_age_all)
    add_age_lines(ax1)
    for race_name, data in RACE_DATA.items():
        ages, stats = compute_stat_curve(race_name, data)
        ax1.plot(ages, stats, label=race_name, color=race_colors[race_name], linewidth=2)
    ax1.legend(loc="upper right", ncol=3, fontsize=9)
    ax1.grid(True, alpha=0.3)

    # 2. stat curves (normalized for comparison)
    ax2 = fig.add_subplot(gs[1])
    ax2.set_title("Physical Stat Curve by Race - Normalized (% of Career)", fontsize=14, fontweight="bold")
    ax2.set_xlabel("Career Progress (0% = start adventuring, 100% = max age)")
    ax2.set_ylabel("Stat %")
    ax2.set_ylim(0, 110)
    ax2.set_xlim(0, 100)
    for race_name, data in RACE_DATA.items():
        ages, stats = compute_stat_curve(race_name, data)
        lifespan = data["max_age"] - data["start_age"]
        normalized = [(a - data["start_age"]) / lifespan * 100 for a in ages]
        ax2.plot(normalized, stats, label=race_name, color=race_colors[race_name], linewidth=2)
    ax2.legend(loc="lower left", ncol=3, fontsize=9)
    ax2.grid(True, alpha=0.3)

    # 3. death chance (absolute age)
    ax3 = fig.add_subplot(gs[2])
    ax3.set_title("Death-from-Old-Age Chance per Rest Event (%)", fontsize=14, fontweight="bold")
    ax3.set_xlabel("Age (years)")
    ax3.set_ylabel("Death Chance %")
    ax3.set_xlim(0, max_age_all)
    add_age_lines(ax3)
    for race_name, data in RACE_DATA.items():
        ages, chances = compute_death_chance(race_name, data)
        ax3.plot(ages, chances, label=race_name, color=race_colors[race_name], linewidth=2)
    ax3.legend(loc="upper left", ncol=3, fontsize=9)
    ax3.grid(True, alpha=0.3)

    # 4. career duration
    ax4 = fig.add_subplot(gs[3])
    ax4.set_title("Career Duration: Years from Start to End of Prime", fontsize=14, fontweight="bold")
    career_years = [RACE_DATA[r]["prime_end"] - RACE_DATA[r]["start_age"] for r in race_names]
    bars = ax4.barh(race_names, career_years, color=[race_colors[r] for r in race_names])
    ax4.set_xlabel("Career Years (Start Age to End of Prime)")
    for bar, years in zip(bars, career_years):
        ax4.text(bar.get_width() + 2, bar.get_y() + bar.get_height()/2, str(years),
                va="center", fontsize=10)
    ax4.grid(True, alpha=0.3, axis="x")

    # 5. level over absolute age (best class) - with age gridlines
    ax5 = fig.add_subplot(gs[4])
    ax5.set_title(
        f"Level Progression Over Lifetime (Best Class, {ENCOUNTERS_PER_YEAR} enc/yr, "
        f"{YEARS_PER_FLOOR_CLEAR} yrs/floor)",
        fontsize=14, fontweight="bold")
    ax5.set_xlabel("Age (years)")
    ax5.set_ylabel("Level")
    ax5.set_ylim(0, 22)
    ax5.set_xlim(0, max_age_all)
    ax5.set_yticks(range(0, 21, 2))
    add_age_lines(ax5)
    for race_name, data in RACE_DATA.items():
        mods = XP_MODIFIERS[race_name]
        best_class = min(mods, key=mods.get)
        best_mod = mods[best_class]
        career = simulate_career(race_name, data, best_class, best_mod)
        ages = [y["age"] for y in career]
        levels = [y["level"] for y in career]
        prime_level = find_level_at_age(career, data["prime_end"])
        ax5.plot(ages, levels, label=f"{race_name} ({best_class})",
                color=race_colors[race_name], linewidth=2)
        ax5.plot(data["prime_end"], prime_level, "o", color=race_colors[race_name],
                markersize=6, markeredgecolor="black", markeredgewidth=0.5)
    ax5.axhline(y=20, color="gray", linestyle="--", alpha=0.5, label="Max Level")
    ax5.legend(loc="center right", ncol=2, fontsize=8)
    ax5.grid(True, alpha=0.3)

    # 6. floor reached over absolute age
    ax6 = fig.add_subplot(gs[5])
    ax6.set_title("Deepest Floor Reached Over Lifetime (Best Class)", fontsize=14, fontweight="bold")
    ax6.set_xlabel("Age (years)")
    ax6.set_ylabel("Floor")
    ax6.set_xlim(0, max_age_all)
    add_age_lines(ax6)
    for race_name, data in RACE_DATA.items():
        mods = XP_MODIFIERS[race_name]
        best_class = min(mods, key=mods.get)
        best_mod = mods[best_class]
        career = simulate_career(race_name, data, best_class, best_mod)
        ages = [y["age"] for y in career]
        floors = [y["floor"] for y in career]
        ax6.plot(ages, floors, label=race_name, color=race_colors[race_name], linewidth=2)
    ax6.legend(loc="center right", ncol=2, fontsize=8)
    ax6.grid(True, alpha=0.3)

    # 7. xp per year (absolute age)
    ax7 = fig.add_subplot(gs[6])
    ax7.set_title("XP Earned Per Year Over Lifetime (Best Class)",
                  fontsize=14, fontweight="bold")
    ax7.set_xlabel("Age (years)")
    ax7.set_ylabel("XP / Year")
    ax7.set_yscale("log")
    ax7.set_xlim(0, max_age_all)
    add_age_lines(ax7)
    for race_name, data in RACE_DATA.items():
        mods = XP_MODIFIERS[race_name]
        best_class = min(mods, key=mods.get)
        best_mod = mods[best_class]
        career = simulate_career(race_name, data, best_class, best_mod)
        ages = [y["age"] for y in career]
        xpy = [y["xp_this_year"] for y in career]
        ax7.plot(ages, xpy, label=race_name, color=race_colors[race_name], linewidth=2)
    ax7.legend(loc="upper left", ncol=3, fontsize=8)
    ax7.grid(True, alpha=0.3)

    # 8. best vs worst: level at START OF DECLINE
    ax8 = fig.add_subplot(gs[7])
    ax8.set_title("Best vs Worst Class: Level When Decline Begins",
                  fontsize=14, fontweight="bold")
    x = np.arange(len(race_names))
    bar_width = 0.35

    best_levels_decline = []
    worst_levels_decline = []
    best_names = []
    worst_names = []
    for race_name in race_names:
        data = RACE_DATA[race_name]
        mods = XP_MODIFIERS[race_name]
        best_class = min(mods, key=mods.get)
        worst_class = max(mods, key=mods.get)
        best_career = simulate_career(race_name, data, best_class, mods[best_class])
        worst_career = simulate_career(race_name, data, worst_class, mods[worst_class])
        best_levels_decline.append(find_level_at_age(best_career, data["prime_end"]))
        worst_levels_decline.append(find_level_at_age(worst_career, data["prime_end"]))
        best_names.append(best_class)
        worst_names.append(worst_class)

    bars_best = ax8.bar(x - bar_width/2, best_levels_decline, bar_width,
                        label="Best Class", color="steelblue")
    bars_worst = ax8.bar(x + bar_width/2, worst_levels_decline, bar_width,
                         label="Worst Class", color="indianred")
    ax8.set_xticks(x)
    ax8.set_xticklabels(race_names, rotation=45, ha="right")
    ax8.set_ylabel("Level at Start of Decline")
    ax8.set_ylim(0, 22)
    ax8.set_yticks(range(0, 21, 2))
    ax8.axhline(y=20, color="gray", linestyle="--", alpha=0.5)
    ax8.legend(fontsize=10)
    ax8.grid(True, alpha=0.3, axis="y")
    for bar, name, level in zip(bars_best, best_names, best_levels_decline):
        ax8.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.3,
                f"{name}\nL{level}", ha="center", va="bottom", fontsize=7)
    for bar, name, level in zip(bars_worst, worst_names, worst_levels_decline):
        ax8.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.3,
                f"{name}\nL{level}", ha="center", va="bottom", fontsize=7)

    # 9. "generations raised" - how many short-lived race lifetimes fit in one long-lived career
    ax9 = fig.add_subplot(gs[8])
    ax9.set_title("Generational Overlap: Short-Lived Race Lifetimes per Long-Lived Career",
                  fontsize=14, fontweight="bold")
    long_lived = ["Elf", "Dwarf", "Gnome", "Faerie", "Dracon", "Hobbit"]
    short_lived = ["Human", "Rawulf", "Mook", "Lizman", "Felpurr"]
    ll_careers = {r: RACE_DATA[r]["prime_end"] - RACE_DATA[r]["start_age"] for r in long_lived}
    sl_careers = {r: RACE_DATA[r]["prime_end"] - RACE_DATA[r]["start_age"] for r in short_lived}

    x_pos = np.arange(len(long_lived))
    width_per_short = 0.15
    offsets = np.linspace(-(len(short_lived)-1)/2 * width_per_short,
                          (len(short_lived)-1)/2 * width_per_short,
                          len(short_lived))
    sl_colors = {"Human": "#4477AA", "Rawulf": "#EE6677", "Mook": "#228833",
                 "Lizman": "#CCBB44", "Felpurr": "#AA3377"}
    for j, sl_race in enumerate(short_lived):
        generations = [ll_careers[ll_race] / sl_careers[sl_race] for ll_race in long_lived]
        bars = ax9.bar(x_pos + offsets[j], generations, width_per_short,
                      label=f"{sl_race} ({sl_careers[sl_race]}yr career)",
                      color=sl_colors[sl_race])
        for bar, gen in zip(bars, generations):
            ax9.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.1,
                    f"{gen:.1f}", ha="center", va="bottom", fontsize=6)
    ax9.set_xticks(x_pos)
    ax9.set_xticklabels([f"{r}\n({ll_careers[r]}yr)" for r in long_lived], fontsize=9)
    ax9.set_ylabel("Number of Short-Lived Lifetimes")
    ax9.legend(fontsize=8, loc="upper left")
    ax9.grid(True, alpha=0.3, axis="y")

    # 10. timeline view - stacked generations alongside a single elf career
    ax10 = fig.add_subplot(gs[9])
    ax10.set_title("Timeline: One Elf Mage's Career vs Generations of Companions",
                   fontsize=14, fontweight="bold")
    ax10.set_xlabel("Career Years Elapsed")
    ax10.set_ylabel("")

    elf_data = RACE_DATA["Elf"]
    elf_career = elf_data["prime_end"] - elf_data["start_age"]

    companion_races = ["Human", "Rawulf", "Mook", "Lizman", "Felpurr", "Hobbit", "Dwarf"]
    y_positions = list(range(len(companion_races) + 1))

    # draw the elf bar
    elf_mods = XP_MODIFIERS["Elf"]
    elf_best = min(elf_mods, key=elf_mods.get)
    elf_sim = simulate_career("Elf", elf_data, elf_best, elf_mods[elf_best])
    elf_age_20 = find_age_at_level(elf_sim, 20)
    elf_years_to_20 = (elf_age_20 - elf_data["start_age"]) if elf_age_20 else elf_career

    ax10.barh(len(companion_races), elf_career, color="darkorange", alpha=0.8, height=0.6)
    ax10.barh(len(companion_races), elf_years_to_20, color="gold", alpha=0.6, height=0.6)
    ax10.text(elf_career / 2, len(companion_races),
             f"Elf {elf_best} - {elf_career}yr career (L20 at yr {elf_years_to_20})",
             ha="center", va="center", fontsize=9, fontweight="bold")

    for i, comp_race in enumerate(companion_races):
        comp_data = RACE_DATA[comp_race]
        comp_career = comp_data["prime_end"] - comp_data["start_age"]
        comp_mods = XP_MODIFIERS[comp_race]
        comp_best = min(comp_mods, key=comp_mods.get)
        comp_sim = simulate_career(comp_race, comp_data, comp_best, comp_mods[comp_best])
        comp_level_at_decline = find_level_at_age(comp_sim, comp_data["prime_end"])

        generation = 0
        offset = 0
        gen_colors = plt.cm.Set3(np.linspace(0, 1, 20))
        while offset < elf_career:
            bar_len = min(comp_career, elf_career - offset)
            ax10.barh(i, bar_len, left=offset, color=gen_colors[generation % 20],
                     alpha=0.7, height=0.6, edgecolor="black", linewidth=0.5)
            if bar_len > 15:
                ax10.text(offset + bar_len / 2, i,
                         f"G{generation+1}\nL{comp_level_at_decline}",
                         ha="center", va="center", fontsize=7)
            offset += comp_career
            generation += 1

    ax10.set_yticks(y_positions)
    ax10.set_yticklabels(companion_races + ["Elf"], fontsize=10)
    ax10.set_xlim(0, elf_career + 10)
    add_age_lines(ax10)
    ax10.grid(True, alpha=0.3, axis="x")

    plt.savefig(output_path, dpi=150, bbox_inches="tight")
    print(f"Charts saved to {output_path}")

    print(f"\n--- Simulation Parameters ---")
    print(f"  Encounters/year: {ENCOUNTERS_PER_YEAR}")
    print(f"  Years to clear a floor: {YEARS_PER_FLOOR_CLEAR}")
    print(f"  Party size (XP split): {PARTY_SIZE}")

    print(f"\n--- Level at Start of Decline (Best vs Worst Class) ---")
    header = (f"{'Race':<10} {'Best':<10} {'Mod':>4} {'@Decline':>8}  "
              f"{'Worst':<10} {'Mod':>4} {'@Decline':>8}  {'Gap':>4}  "
              f"{'PrimeYrs':>8}")
    print(header)
    print("-" * len(header))
    for i, race_name in enumerate(race_names):
        data = RACE_DATA[race_name]
        mods = XP_MODIFIERS[race_name]
        best_class = min(mods, key=mods.get)
        worst_class = max(mods, key=mods.get)
        gap = best_levels_decline[i] - worst_levels_decline[i]
        prime_yrs = data["prime_end"] - data["start_age"]
        print(f"{race_name:<10} {best_class:<10} {mods[best_class]:>4.1f} {'L' + str(best_levels_decline[i]):>8}  "
              f"{worst_class:<10} {mods[worst_class]:>4.1f} {'L' + str(worst_levels_decline[i]):>8}  "
              f"{gap:>+3}   {prime_yrs:>6}yr")

    print(f"\n--- Generational Overlap ---")
    print(f"{'Long-lived':<12} {'Career':>7} | ", end="")
    for sl in short_lived:
        print(f"{sl:>8}", end="")
    print()
    print("-" * 60)
    for ll_race in long_lived:
        ll_yrs = ll_careers[ll_race]
        print(f"{ll_race:<12} {ll_yrs:>5}yr | ", end="")
        for sl_race in short_lived:
            gen = ll_yrs / sl_careers[sl_race]
            print(f"{gen:>7.1f}x", end="")
        print()


def print_comparison():
    proposed_monk = build_proposed_modifiers("Monk")
    proposed_mage = build_proposed_modifiers("Mage")

    print("\n" + "=" * 90)
    print("PROPOSED MODIFIER CHANGES")
    print("=" * 90)
    print(f"{'Race':<10} {'Class':<10} {'Current':>8} {'Proposed':>8} {'Change':>8}")
    print("-" * 50)
    for race, changes in PROPOSED_CHANGES.items():
        display_race = race.replace("_", " ") if "Mook" in race else race
        for cls, new_val in changes.items():
            if race.startswith("Mook_"):
                old_val = XP_MODIFIERS_CURRENT["Mook"][cls]
            else:
                old_val = XP_MODIFIERS_CURRENT[race][cls]
            print(f"{display_race:<10} {cls:<10} {old_val:>8.1f} {new_val:>8.1f} {new_val - old_val:>+8.1f}")

    print("\n" + "=" * 90)
    print("SPEED CHAMPION PER CLASS (Who hits each level first?)")
    print("=" * 90)
    basic_classes = ["Fighter", "Mage", "Priest", "Thief"]
    hybrid_classes = ["Ranger", "Bard", "Bishop", "Alchemist", "Psionic"]
    elite_classes = ["Valkyrie", "Samurai", "Lord", "Monk", "Ninja"]

    for label, class_group in [("BASIC", basic_classes), ("HYBRID", hybrid_classes),
                                ("ELITE", elite_classes)]:
        print(f"\n  {label} CLASSES:")
        print(f"  {'Class':<12} {'Current Champion':<22} {'Mod':>4}  {'Proposed Champion':<22} {'Mod':>4}")
        print("  " + "-" * 72)
        for cls in class_group:
            cur_best_race = min(XP_MODIFIERS_CURRENT.keys(),
                               key=lambda r: XP_MODIFIERS_CURRENT[r].get(cls, 9))
            cur_mod = XP_MODIFIERS_CURRENT[cur_best_race][cls]
            prop_best_race = min(proposed_monk.keys(),
                                key=lambda r: proposed_monk[r].get(cls, 9))
            prop_mod = proposed_monk[prop_best_race][cls]
            cur_lifespan = "short" if RACE_DATA[cur_best_race]["prime_end"] - RACE_DATA[cur_best_race]["start_age"] < 50 else "long"
            prop_lifespan = "short" if RACE_DATA[prop_best_race]["prime_end"] - RACE_DATA[prop_best_race]["start_age"] < 50 else "long"
            print(f"  {cls:<12} {cur_best_race + ' (' + cur_lifespan + ')':<22} {cur_mod:>4.1f}  "
                  f"{prop_best_race + ' (' + prop_lifespan + ')':<22} {prop_mod:>4.1f}")

    print("\n" + "=" * 90)
    print("EARLY CAREER COMPARISON: Level at Year 5/10/15/20 (Best Class)")
    print("=" * 90)
    race_names = list(RACE_DATA.keys())
    milestones = [5, 10, 15, 20]

    header = f"{'Race':<10} {'Class':<10} {'Mod':>4}"
    for yr in milestones:
        header += f"  {'Yr'+str(yr):>5}"
    header += f"  {'@Decline':>9} {'PrimeYrs':>9}"
    print(header)
    print("-" * len(header))

    for scenario_name, mods_dict in [("CURRENT", XP_MODIFIERS_CURRENT),
                                      ("PROPOSED (Mook=Monk)", proposed_monk)]:
        print(f"\n  [{scenario_name}]")
        for race_name in race_names:
            data = RACE_DATA[race_name]
            mods = mods_dict[race_name]
            best_class = min(mods, key=mods.get)
            best_mod = mods[best_class]
            career = simulate_career(race_name, data, best_class, best_mod)

            row = f"  {race_name:<10} {best_class:<10} {best_mod:>4.1f}"
            for yr in milestones:
                target_age = data["start_age"] + yr
                if target_age <= data["max_age"]:
                    lvl = find_level_at_age(career, target_age)
                    row += f"  {'L'+str(lvl):>5}"
                else:
                    row += f"  {'dead':>5}"
            decline_lvl = find_level_at_age(career, data["prime_end"])
            prime_yrs = data["prime_end"] - data["start_age"]
            row += f"  {'L'+str(decline_lvl):>9} {prime_yrs:>7}yr"
            print(row)

    print("\n" + "=" * 90)
    print("MOOK OPTIONS COMPARISON")
    print("=" * 90)
    mook_data = RACE_DATA["Mook"]
    for option, option_mods in [("Current (no specialty)", XP_MODIFIERS_CURRENT),
                                 ("Proposed: Monk @ 0.7", proposed_monk),
                                 ("Proposed: Mage @ 0.7", proposed_mage)]:
        mods = option_mods["Mook"]
        best_class = min(mods, key=mods.get)
        best_mod = mods[best_class]
        career = simulate_career("Mook", mook_data, best_class, best_mod)
        decline_lvl = find_level_at_age(career, mook_data["prime_end"])
        yr5 = find_level_at_age(career, mook_data["start_age"] + 5)
        yr10 = find_level_at_age(career, mook_data["start_age"] + 10)
        yr15 = find_level_at_age(career, mook_data["start_age"] + 15)
        print(f"  {option:<30} Best={best_class:<8} Mod={best_mod:.1f}  "
              f"Yr5=L{yr5}  Yr10=L{yr10}  Yr15=L{yr15}  @Decline=L{decline_lvl}")

    print("\n" + "=" * 90)
    print("STRATEGIC IDENTITY SUMMARY")
    print("=" * 90)
    identities = {
        "Human":   "Generalist filler   - all basic classes at 1.0, moderate lifespan",
        "Elf":     "Eternal investment   - caster (Mage/Priest 0.9), longest shelf life (325yr prime)",
        "Dwarf":   "Long-lived tank     - Fighter 0.9, 130yr at L20",
        "Gnome":   "Long-lived healer   - Priest 0.8, 140yr at L20",
        "Hobbit":  "Long-lived rogue    - Thief 0.8, 50yr at L20",
        "Faerie":  "Long-lived caster   - Mage 0.8 (fastest mage), 125yr at L20",
        "Lizman":  "Sprint Fighter      - Fighter 0.7 (fastest in game), burns out ~20yr",
        "Dracon":  "Breath weapon util  - free AoE every fight, Fighter 0.9, 80yr prime",
        "Rawulf":  "Sprint Priest       - Priest 0.7 (fastest in game), burns out ~19yr",
        "Mook":    "??? NEEDS IDENTITY  - currently a worse Human",
        "Felpurr": "Sprint Thief        - Thief 0.7 (fastest in game), burns out ~23yr",
    }
    for race, identity in identities.items():
        prime_yrs = RACE_DATA[race]["prime_end"] - RACE_DATA[race]["start_age"]
        print(f"  {race:<10} {identity}")


if __name__ == "__main__":
    output = sys.argv[1] if len(sys.argv) > 1 else "tools/age_balance_charts.png"
    plot_all(output)
    print_comparison()
