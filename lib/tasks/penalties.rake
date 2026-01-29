# frozen_string_literal: true

namespace :penalties do
  desc "Load ISMF penalties into database"
  task load: :environment do
    puts "Loading ISMF penalties..."

    penalties_data = [
      {
        "category" => "A",
        "title" => "General – infringements not specifically cited",
        "description" => "Used by ISMF Referee when an infringement is not explicitly listed in categories B, C, D, E or F.",
        "penalties" => [
          {
            "penalty_number" => "A.1",
            "name" => "Cheating, unsportsmanlike conduct or important safety fault",
            "penalties" => {
              "team_individual" => "disqualification",
              "vertical" => "disqualification",
              "sprint_relay" => "disqualification"
            }
          },
          {
            "penalty_number" => "A.2",
            "name" => "Behaviour that may intentionally hinder another competitor",
            "penalties" => {
              "team_individual" => "3 minutes",
              "vertical" => "1 minute",
              "sprint_relay" => "30 seconds"
            }
          },
          {
            "penalty_number" => "A.3",
            "name" => "Minor technical error or involuntary negligence",
            "penalties" => {
              "team_individual" => "30 seconds",
              "vertical" => "10 seconds",
              "sprint_relay" => "3 seconds"
            }
          }
        ]
      },
      {
        "category" => "B",
        "title" => "Equipment",
        "description" => "Penalties related to compulsory equipment, weight limits and electronic systems. Cumulative penalties apply where specified.",
        "penalties" => [
          {
            "penalty_number" => "B.1",
            "name" => "Skis, binding or boot not in compliance with the rules",
            "penalties" => {
              "team_individual" => "disqualification",
              "vertical" => "disqualification",
              "sprint_relay" => "disqualification"
            }
          },
          {
            "penalty_number" => "B.2",
            "name" => "Ski and bindings or boot weight missing between 1 and 20 grams",
            "penalties" => {
              "team_individual" => "30 seconds",
              "vertical" => "10 seconds",
              "sprint_relay" => "3 seconds"
            }
          },
          {
            "penalty_number" => "B.3",
            "name" => "Ski and bindings or boot weight missing 21 grams or more",
            "penalties" => {
              "team_individual" => "disqualification",
              "vertical" => "disqualification",
              "sprint_relay" => "disqualification"
            }
          },
          {
            "penalty_number" => "B.4",
            "name" => "Missing safety equipment or equipment not in compliance (DVA, shovel, probe, helmet, ski brakes, harness, lanyard, karabiners, Via Ferrata kit, headlamp, rope, crampons) at start line",
            "penalties" => {
              "team_individual" => "disqualification",
              "vertical" => "disqualification",
              "sprint_relay" => "disqualification"
            },
            "notes" => "No penalty for equipment broken during the race if proven. Minor cosmetic repairs may be accepted by ISMF Jury President."
          },
          {
            "penalty_number" => "B.5",
            "name" => "Missing or non-compliant clothing or race equipment (clothes, survival blanket, gloves, eyewear, backpack, ski cap, whistle, skins, ID, poles, skis, crampons)",
            "penalties" => {
              "team_individual" => "3 minutes per item missing",
              "vertical" => "1 minute",
              "sprint_relay" => "30 seconds"
            },
            "notes" => "No penalty for equipment broken during the race if proven. Voluntary abandonment of equipment is forbidden. In Sprint and Mixed Relay races crossing the finish line with both poles is mandatory except in defined cases. Unjustified involuntary pole loss in descent results in Penalty A.3."
          },
          {
            "penalty_number" => "B.6",
            "name" => "DVA out of order, dead battery during the race, or DVA switched off after finish line before equipment control",
            "penalties" => {
              "team_individual" => "3 minutes",
              "vertical" => "1 minute",
              "sprint_relay" => "N/A"
            }
          },
          {
            "penalty_number" => "B.7",
            "name" => "Crampon or crampons missing in a foot section with crampons",
            "penalties" => {
              "team_individual" => "disqualification",
              "vertical" => "N/A",
              "sprint_relay" => "N/A"
            }
          },
          {
            "penalty_number" => "B.8",
            "name" => "Head lamp not switched on when required",
            "penalties" => {
              "team_individual" => "3 minutes",
              "vertical" => "1 minute",
              "sprint_relay" => "30 seconds"
            }
          },
          {
            "penalty_number" => "B.9",
            "name" => "Transponder or electronic timing system missing at the start line",
            "penalties" => {
              "team_individual" => "no start",
              "vertical" => "no start",
              "sprint_relay" => "no start"
            }
          },
          {
            "penalty_number" => "B.10",
            "name" => "Transponder or electronic timing system missing at the finish line",
            "penalties" => {
              "team_individual" => "30 seconds",
              "vertical" => "10 seconds",
              "sprint_relay" => "3 seconds"
            }
          }
        ]
      },
      {
        "category" => "C",
        "title" => "Behaviour",
        "description" => "Ignoring correct racing technique, disrespect of markings or itinerary, dangerous actions, jeopardising race safety or proper race conduct, and unsportsmanlike behaviour.",
        "penalties" => [
          {
            "penalty_number" => "C.1",
            "name" => "False start",
            "penalties" => {
              "team_individual" => "3 minutes",
              "vertical" => "1 minute",
              "sprint_relay" => "30 seconds"
            }
          },
          {
            "penalty_number" => "C.2",
            "name" => "Missing checkpoint (voluntary or involuntary)",
            "penalties" => {
              "team_individual" => "disqualification",
              "vertical" => "disqualification",
              "sprint_relay" => "N/A"
            }
          },
          {
            "penalty_number" => "C.3",
            "name" => "Not following the correct track on a ridge",
            "penalties" => {
              "team_individual" => "disqualification",
              "vertical" => "disqualification",
              "sprint_relay" => "N/A"
            }
          },
          {
            "penalty_number" => "C.4",
            "name" => "Missing a gate in a descent section (voluntary or involuntary)",
            "penalties" => {
              "team_individual" => "3 minutes",
              "vertical" => "1 minute",
              "sprint_relay" => "30 seconds"
            }
          },
          {
            "penalty_number" => "C.5",
            "name" => "Dangerous or unsportsmanlike behaviour by not closely following track markings in ascent or descent",
            "penalties" => {
              "team_individual" => "disqualification",
              "vertical" => "disqualification",
              "sprint_relay" => "disqualification"
            }
          },
          {
            "penalty_number" => "C.6",
            "name" => "Disregarding instructions given by an official on the track",
            "penalties" => {
              "team_individual" => "3 minutes",
              "vertical" => "1 minute",
              "sprint_relay" => "30 seconds"
            }
          },
          {
            "penalty_number" => "C.7",
            "name" => "Not respecting the indicated mode of locomotion",
            "penalties" => {
              "team_individual" => "3 minutes",
              "vertical" => "1 minute",
              "sprint_relay" => "30 seconds"
            },
            "notes" => "No penalty if broken equipment and athlete acts to avoid damaging the trail."
          },
          {
            "penalty_number" => "C.8",
            "name" => "Walking without crampons on a compulsory crampon section",
            "penalties" => {
              "team_individual" => "disqualification or 3 minutes if crampons broken",
              "vertical" => "N/A",
              "sprint_relay" => "N/A"
            }
          },
          {
            "penalty_number" => "C.9",
            "name" => "Incorrect fastening of skis on the backpack (less than two fastening points)",
            "penalties" => {
              "team_individual" => "30 seconds",
              "vertical" => "10 seconds",
              "sprint_relay" => "3 seconds"
            }
          },
          {
            "penalty_number" => "C.10",
            "name" => "Incorrect stowage of skins",
            "penalties" => {
              "team_individual" => "30 seconds",
              "vertical" => "10 seconds",
              "sprint_relay" => "3 seconds"
            }
          },
          {
            "penalty_number" => "C.11",
            "name" => "Crampons without straps clipped on the ankles",
            "penalties" => {
              "team_individual" => "3 minutes",
              "vertical" => "N/A",
              "sprint_relay" => "N/A"
            }
          },
          {
            "penalty_number" => "C.12",
            "name" => "Crampons outside the backpack",
            "penalties" => {
              "team_individual" => "3 minutes",
              "vertical" => "N/A",
              "sprint_relay" => "N/A"
            }
          },
          {
            "penalty_number" => "C.13",
            "name" => "Ski poles not placed flat on the ground in a transition area",
            "penalties" => {
              "team_individual" => "30 seconds",
              "vertical" => "10 seconds",
              "sprint_relay" => "3 seconds"
            }
          },
          {
            "penalty_number" => "C.14",
            "name" => "Not clipping the karabiner to a compulsory rope",
            "penalties" => {
              "team_individual" => "3 minutes",
              "vertical" => "N/A",
              "sprint_relay" => "N/A"
            }
          },
          {
            "penalty_number" => "C.15",
            "name" => "Not yielding the track or disrespecting finish area skating corridor rules",
            "penalties" => {
              "team_individual" => "30 seconds",
              "vertical" => "10 seconds",
              "sprint_relay" => "3 seconds"
            }
          },
          {
            "penalty_number" => "C.16",
            "name" => "Pushing, shoving, or making another athlete fall (voluntary)",
            "penalties" => {
              "team_individual" => "disqualification",
              "vertical" => "disqualification",
              "sprint_relay" => "disqualification"
            }
          },
          {
            "penalty_number" => "C.17",
            "name" => "Not rendering assistance to a person in distress or in danger",
            "penalties" => {
              "team_individual" => "3 minutes",
              "vertical" => "1 minute",
              "sprint_relay" => "30 seconds"
            }
          },
          {
            "penalty_number" => "C.18",
            "name" => "Receiving outside help (except changing broken ski in technical zone or poles)",
            "penalties" => {
              "team_individual" => "3 minutes",
              "vertical" => "1 minute",
              "sprint_relay" => "30 seconds"
            }
          },
          {
            "penalty_number" => "C.19",
            "name" => "Disrespecting the environment",
            "penalties" => {
              "team_individual" => "3 minutes",
              "vertical" => "1 minute",
              "sprint_relay" => "30 seconds"
            }
          },
          {
            "penalty_number" => "C.20",
            "name" => "Disrespecting or insulting participants or damaging ISMF image during the race",
            "penalties" => {
              "team_individual" => "disqualification",
              "vertical" => "disqualification",
              "sprint_relay" => "disqualification"
            },
            "notes" => "ISMF Technical Jury must prepare a report and refer the case to the Disciplinary Commission."
          },
          {
            "penalty_number" => "C.21",
            "name" => "Disrespecting or insulting participants or damaging ISMF image outside the race",
            "penalties" => {
              "team_individual" => "disciplinary referral",
              "vertical" => "disciplinary referral",
              "sprint_relay" => "disciplinary referral"
            }
          },
          {
            "penalty_number" => "C.22",
            "name" => "Non presence at ceremonies",
            "penalties" => {
              "team_individual" => "no prize money",
              "vertical" => "no prize money",
              "sprint_relay" => "no prize money"
            }
          },
          {
            "penalty_number" => "C.23",
            "name" => "Incorrect manoeuvre in the transition area",
            "penalties" => {
              "team_individual" => "30 seconds",
              "vertical" => "10 seconds",
              "sprint_relay" => "3 seconds"
            }
          },
          {
            "penalty_number" => "C.24",
            "name" => "Abandon or DNS without informing the organisation",
            "penalties" => {
              "team_individual" => "start in rear part of following race (100 EUR)",
              "vertical" => "N/A",
              "sprint_relay" => "N/A"
            }
          }
        ]
      },
      {
        "category" => "D",
        "title" => "Team race specific",
        "description" => "Penalties specific to Team races, applying only when athletes are competing as a team.",
        "penalties" => [
          {
            "penalty_number" => "D.1",
            "name" => "Team members separated by more than allowed time or distance",
            "penalties" => {
              "team_individual" => "3 minutes",
              "vertical" => "N/A",
              "sprint_relay" => "N/A"
            }
          },
          {
            "penalty_number" => "D.2",
            "name" => "Team members not respecting required order during the race",
            "penalties" => {
              "team_individual" => "3 minutes",
              "vertical" => "N/A",
              "sprint_relay" => "N/A"
            }
          },
          {
            "penalty_number" => "D.3",
            "name" => "Team members not crossing the finish line together",
            "penalties" => {
              "team_individual" => "disqualification",
              "vertical" => "N/A",
              "sprint_relay" => "N/A"
            }
          },
          {
            "penalty_number" => "D.4",
            "name" => "Team members not helping each other when required",
            "penalties" => {
              "team_individual" => "3 minutes",
              "vertical" => "N/A",
              "sprint_relay" => "N/A"
            }
          },
          {
            "penalty_number" => "D.5",
            "name" => "Use of rope in a non-compulsory section",
            "penalties" => {
              "team_individual" => "3 minutes",
              "vertical" => "N/A",
              "sprint_relay" => "N/A"
            }
          },
          {
            "penalty_number" => "D.6",
            "name" => "Not using rope in a compulsory section",
            "penalties" => {
              "team_individual" => "disqualification",
              "vertical" => "N/A",
              "sprint_relay" => "N/A"
            }
          },
          {
            "penalty_number" => "D.7",
            "name" => "Incorrect rope handling or rope not in compliance",
            "penalties" => {
              "team_individual" => "3 minutes",
              "vertical" => "N/A",
              "sprint_relay" => "N/A"
            }
          }
        ]
      },
      {
        "category" => "E",
        "title" => "Relay race specific",
        "description" => "Penalties applying only to Relay and Mixed Relay races.",
        "penalties" => [
          {
            "penalty_number" => "E.1",
            "name" => "Relay exchange outside the designated relay zone",
            "penalties" => {
              "team_individual" => "N/A",
              "vertical" => "N/A",
              "sprint_relay" => "30 seconds"
            }
          },
          {
            "penalty_number" => "E.2",
            "name" => "Early relay exchange (incoming athlete has not crossed the relay line)",
            "penalties" => {
              "team_individual" => "N/A",
              "vertical" => "N/A",
              "sprint_relay" => "30 seconds"
            }
          },
          {
            "penalty_number" => "E.3",
            "name" => "Relay athlete not respecting the correct course",
            "penalties" => {
              "team_individual" => "N/A",
              "vertical" => "N/A",
              "sprint_relay" => "disqualification"
            }
          }
        ]
      },
      {
        "category" => "F",
        "title" => "Coaches and officials",
        "description" => "Penalties related to behaviour and actions of coaches, team officials, and accompanying persons.",
        "penalties" => [
          {
            "penalty_number" => "F.1",
            "name" => "Accessing the race course or restricted areas without authorisation",
            "penalties" => {
              "team_individual" => "3 minutes",
              "vertical" => "1 minute",
              "sprint_relay" => "30 seconds"
            },
            "notes" => "Penalty is applied to the athlete or team associated with the coach or official."
          },
          {
            "penalty_number" => "F.2",
            "name" => "Providing assistance to an athlete outside authorised zones",
            "penalties" => {
              "team_individual" => "3 minutes",
              "vertical" => "1 minute",
              "sprint_relay" => "30 seconds"
            },
            "notes" => "Includes pacing, physical help, or equipment assistance."
          },
          {
            "penalty_number" => "F.3",
            "name" => "Interfering with other competitors",
            "penalties" => {
              "team_individual" => "disqualification",
              "vertical" => "disqualification",
              "sprint_relay" => "disqualification"
            }
          },
          {
            "penalty_number" => "F.4",
            "name" => "Unsportsmanlike behaviour or disrespect towards officials, athletes, or organisers",
            "penalties" => {
              "team_individual" => "disqualification",
              "vertical" => "disqualification",
              "sprint_relay" => "disqualification"
            },
            "notes" => "May be referred to ISMF Disciplinary Commission."
          },
          {
            "penalty_number" => "F.5",
            "name" => "Failure to comply with instructions from race officials",
            "penalties" => {
              "team_individual" => "3 minutes",
              "vertical" => "1 minute",
              "sprint_relay" => "30 seconds"
            }
          }
        ]
      }
    ]

    penalty_count = 0
    penalties_data.each do |category_data|
      category_data["penalties"].each do |penalty_data|
        penalty = Penalty.find_or_initialize_by(penalty_number: penalty_data["penalty_number"])
        penalty.assign_attributes(
          category: category_data["category"],
          category_title: category_data["title"],
          category_description: category_data["description"],
          name: penalty_data["name"],
          team_individual: penalty_data["penalties"]["team_individual"],
          vertical: penalty_data["penalties"]["vertical"],
          sprint_relay: penalty_data["penalties"]["sprint_relay"],
          notes: penalty_data["notes"]
        )

        if penalty.save
          puts "  ✓ #{penalty.penalty_number} - #{penalty.name}"
          penalty_count += 1
        else
          puts "  ✗ Failed to create #{penalty_data['penalty_number']}: #{penalty.errors.full_messages.join(', ')}"
        end
      end
    end

    puts ""
    puts "✅ Created/updated #{penalty_count} penalties across #{penalties_data.length} categories"
    puts ""
    puts "Penalties by category:"
    penalties_data.each do |cat|
      count = Penalty.where(category: cat["category"]).count
      puts "  #{cat['category']}: #{cat['title']} (#{count} penalties)"
    end
  end
end