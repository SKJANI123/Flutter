import 'package:flutter/material.dart';

import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/presentation/theme/app_theme.dart';

/// One survival guide entry for a hazard. [before]/[during]/[after] carry the
/// actionable steps shown on the detail page.
class HazardGuide {
  const HazardGuide({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.before,
    required this.during,
    required this.after,
  });

  final String id;
  final DisasterType? type;
  final String title;
  final String subtitle;
  final List<String> before;
  final List<String> during;
  final List<String> after;

  IconData get icon => AppTheme.typeIcon(type ?? DisasterType.storm);
}

class GuideData {
  GuideData._();

  static const guides = <HazardGuide>[
    HazardGuide(
      id: 'earthquake',
      type: DisasterType.earthquake,
      title: 'Earthquake',
      subtitle: 'Drop, cover and hold on. Stay away from windows and shelves.',
      before: [
        'Secure heavy furniture, appliances and shelves to walls before shaking starts.',
        'Identify safe spots: under sturdy tables or against interior walls away from windows.',
        'Prepare an emergency bag with water, food, torch, documents and medicines.',
        'Know how to shut off gas and electricity at the mains.',
      ],
      during: [
        'DROP to the ground, COVER under a sturdy table, HOLD ON until shaking stops.',
        'If you are indoors, stay there. Do not run outside or use lifts.',
        'Stay away from windows, glass, tall furniture and hanging objects.',
        'If outdoors, move to an open area away from buildings, trees and power lines.',
        'If driving, pull over to a clear spot and remain in the vehicle.',
      ],
      after: [
        'Check yourself and others for injuries; give first aid if needed.',
        'Expect aftershocks. Move to open ground if the building is damaged.',
        'Turn off gas and electricity if you smell gas or see sparks.',
        'Use the torch — do not light matches or candles.',
        'Share status through the app’s SOS feature and wait for official updates.',
      ],
    ),
    HazardGuide(
      id: 'flood',
      type: DisasterType.flood,
      title: 'Flood',
      subtitle: 'Move to higher ground immediately. Never walk or drive through water.',
      before: [
        'Know whether you live in a flood-prone area and the nearest high ground.',
        'Stock drinking water, dry food, torch, a phone power bank and medicines.',
        'Move valuables, electrical items and documents to upper floors.',
        'Keep sandbags or boards ready to block doorways if waters rise.',
      ],
      during: [
        'Move to high ground or an upper floor immediately.',
        'Never walk, swim or drive through floodwater — six inches can knock you over.',
        'Do not touch electrical wires or appliances standing in water.',
        'Listen for official evacuation orders and leave when told to.',
        'Move children, elderly and pets with you; keep contact numbers at hand.',
      ],
      after: [
        'Return home only when authorities confirm it is safe.',
        'Avoid floodwater: it may be polluted or carry debris.',
        'Do not drink or use tap water until it is declared safe.',
        'Photograph damage for insurance and report blocked drains.',
        'Beware of weakened floors, walls and hanging ceilings.',
      ],
    ),
    HazardGuide(
      id: 'cyclone',
      type: DisasterType.cyclone,
      title: 'Cyclone',
      subtitle: 'Board up windows, stock supplies and follow evacuation orders.',
      before: [
        'Listen to weather warnings; do not ignore cyclone alerts.',
        'Secure or bring indoors loose items like furniture, tools and plants.',
        'Stock food, drinking water, torch, battery radio, power bank and cash.',
        'Trim trees and strong branches near your home.',
      ],
      during: [
        'Stay inside in the strongest room, away from windows and doors.',
        'Switch off electricity and gas if instructed.',
        'Do not go out to watch the storm.',
        'If the eye of the storm passes, do not leave shelter — winds will return.',
        'Keep away from the sea, rivers and low-lying ground.',
      ],
      after: [
        'Stay indoors until the official “all clear” is given.',
        'Watch out for fallen power lines, trees and open manholes.',
        'Do not drink water from flooded sources until tested.',
        'Report damage and blocked roads through official channels.',
      ],
    ),
    HazardGuide(
      id: 'tsunami',
      type: DisasterType.tsunami,
      title: 'Tsunami',
      subtitle: 'If it shakes, GO high. A strong quake near the coast can trigger a wave.',
      before: [
        'Know your evacuation route to high ground (at least 30 m above sea level).',
        'Understand natural warnings: a strong earthquake, a receding shore, a roar.',
        'Keep a go-bag ready if you live or work near the coast.',
      ],
      during: [
        'If you feel a strong earthquake near the coast, move inland and uphill immediately.',
        'Do NOT wait for an official warning if the sea suddenly recedes.',
        'Leave the beach, harbours and river mouths at once.',
        'Never go to the shore to watch an incoming wave.',
        'If you are in a boat, head to deep ocean water, not the shore.',
      ],
      after: [
        'Stay on high ground — multiple waves can arrive for hours.',
        'Wait for the official all-clear before returning.',
        'Stay away from damaged buildings and debris on the shoreline.',
        'Check for injuries and provide first aid to those who need it.',
      ],
    ),
    HazardGuide(
      id: 'landslide',
      type: DisasterType.landslide,
      title: 'Landslide',
      subtitle: 'Watch for cracking ground. Move away from slopes when it starts to move.',
      before: [
        'Avoid building or camping near steep slopes and drainage channels.',
        'Watch for warning signs: new cracks in the ground, bulging soil, tilted trees.',
        'Know the safe route away from the hazard area.',
      ],
      during: [
        'Move away from the path of the slide — downslope or to the side.',
        'Do not go near the slide area to take videos or inspect damage.',
        'If you are indoors, take cover under a sturdy table and protect your head.',
        'If driving, turn around — do not try to cross a moving slide.',
      ],
      after: [
        'Stay away from the slide area — further slides can occur.',
        'Listen for the sound of flowing mud or moving rocks; leave quickly if heard.',
        'Check gas lines, power lines and water pipes for damage.',
        'Report blocked roads and injured people to authorities.',
      ],
    ),
    HazardGuide(
      id: 'wildfire',
      type: DisasterType.wildfire,
      title: 'Wildfire',
      subtitle: 'Prepare an escape route. Never put yourself between a fire and high ground.',
      before: [
        'Clear dry leaves, brush and flammable material around your home.',
        'Prepare a go-bag and know at least two escape routes.',
        'Keep gutters clear and store gasoline away from the house.',
        'Make a family plan for where to meet after evacuation.',
      ],
      during: [
        'Evacuate early and calmly when advised — do not return for belongings.',
        'If trapped, shelter in a clear area or a building away from forest.',
        'Wet a cloth over breathing, cover exposed skin and stay low.',
        'Close windows, doors and vents; remove curtains where possible.',
      ],
      after: [
        'Do not return until authorities say it is safe.',
        'Check for smoke, sparks and smouldering debris around your property.',
        'Stay away from burned trees and weakened structures.',
        'Drink safe water only; smoke can affect breathing — limit exposure.',
      ],
    ),
    HazardGuide(
      id: 'heavy_rain',
      type: DisasterType.heavyRain,
      title: 'Heavy Rain',
      subtitle: 'Avoid flooded roads and low areas. Stay indoors during cloudbursts.',
      before: [
        'Clear drains and gutters near your home.',
        'Keep emergency numbers and a torch accessible.',
        'Avoid parking or living in basements and low-lying areas.',
      ],
      during: [
        'Stay indoors and away from windows during lightning.',
        'Never drive or walk through flooded underpasses or roads.',
        'Switch off power to rooms that may flood.',
        'Keep children away from open drains and water bodies.',
      ],
      after: [
        'Be wary of weakened structures and falling trees.',
        'Beware of contaminated flood water and water-borne diseases.',
        'Report waterlogging and blocked drains to the municipality.',
      ],
    ),
    HazardGuide(
      id: 'lightning',
      type: DisasterType.lightning,
      title: 'Lightning',
      subtitle: 'When thunder roars, go indoors. Avoid open fields and tall objects.',
      before: [
        'Check the forecast before outdoor activities in storm season.',
        'Identify safe shelter: a substantial building or a metal-roofed car.',
        'Keep a battery radio for weather updates.',
      ],
      during: [
        'Go indoors when you hear thunder. The 30-30 rule: 30 seconds between flash and boom means seek shelter.',
        'Stay away from windows, doors, electrical wiring, pipes and corded phones.',
        'Avoid open fields, hilltops, water, umbrellas, golf clubs and bikes.',
        'If caught outside, crouch low on the balls of your feet in a hollow.',
        'Never shelter under isolated trees.',
      ],
      after: [
        'Wait at least 30 minutes after the last thunder before resuming activities.',
        'Check for injured people; lightning victims are safe to touch — begin first aid/CPR.',
        'Check for damage to power lines and report fallen wires.',
      ],
    ),
    HazardGuide(
      id: 'storm',
      type: DisasterType.storm,
      title: 'Storm',
      subtitle: 'Secure loose items, stay indoors and avoid windows and power lines.',
      before: [
        'Secure doors, windows and loose outdoor items.',
        'Charge phones and keep a torch and emergency radio ready.',
        'Know the difference between a storm watch and a storm warning.',
      ],
      during: [
        'Stay indoors in an interior room away from windows.',
        'Avoid using corded phones and electrical appliances.',
        'Do not stand near trees, poles, signs or metal fences.',
        'If driving, park away from trees and power lines and stay in the car.',
      ],
      after: [
        'Beware of downed power lines — treat all as live.',
        'Watch for fallen trees, debris and damaged roofs.',
        'Report outages and hazards to the utility company.',
      ],
    ),
    HazardGuide(
      id: 'extreme_heat',
      type: DisasterType.extremeHeat,
      title: 'Extreme Heat',
      subtitle: 'Hydrate, stay indoors at midday and check on the elderly and children.',
      before: [
        'Stock water and electrolytes; keep light clothing and a fan ready.',
        'Plan outdoor work for early morning or evening.',
        'Identify cool places: malls, libraries or shelters with power.',
      ],
      during: [
        'Drink water regularly — do not wait until you are thirsty.',
        'Avoid outdoor activity between 11 am and 4 pm.',
        'Wear light, loose, light-coloured clothing and a hat outside.',
        'Watch for heatstroke signs: dizziness, nausea, confusion, no sweating.',
        'Move to shade or a cool place and cool the body with wet cloths if overheated.',
      ],
      after: [
        'Continue hydrating and avoid strenuous activity until cool of evening.',
        'Check on elderly neighbours, children and pets.',
        'Seek medical help if anyone shows heatstroke symptoms.',
      ],
    ),
    HazardGuide(
      id: 'volcano',
      type: DisasterType.volcano,
      title: 'Volcano',
      subtitle: 'Evacuate early. Ash is harmful — protect eyes and breathing.',
      before: [
        'Know your evacuation route and listen to official alerts.',
        'Prepare a go-bag with N95 masks, goggles, water and food.',
        'Understand the exclusion zones around the volcano.',
      ],
      during: [
        'Evacuate when advised — lahars (mud flows) can travel far and fast.',
        'If ash falls, stay indoors with windows and doors shut.',
        'Wear a mask or wet cloth, and goggles to protect eyes.',
        'Stay away from river valleys and low ground near the volcano.',
      ],
      after: [
        'Do not return until authorities approve re-entry.',
        'Clear ash from roofs — heavy ash can collapse structures.',
        'Wear a mask while cleaning; use hoses rather than brooms when possible.',
        'Filter water and protect electronic equipment from ash',
      ],
    ),
  ];

  static HazardGuide? byId(String id) {
    for (final g in guides) {
      if (g.id == id) return g;
    }
    return null;
  }

  static HazardGuide? byType(DisasterType? type) {
    if (type == null) return null;
    for (final g in guides) {
      if (g.type == type) return g;
    }
    return null;
  }
}

/// Offline, always-available survival guide: Before / During / After
/// instructions per hazard. Reached from Home quick actions and More menu.
class SurvivalGuideScreen extends StatefulWidget {
  const SurvivalGuideScreen({super.key});

  @override
  State<SurvivalGuideScreen> createState() => _SurvivalGuideScreenState();
}

class _SurvivalGuideScreenState extends State<SurvivalGuideScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.trim().isEmpty
        ? GuideData.guides
        : GuideData.guides
              .where(
                (g) =>
                    g.title.toLowerCase().contains(_query.trim().toLowerCase()) ||
                    g.subtitle
                        .toLowerCase()
                        .contains(_query.trim().toLowerCase()),
              )
              .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Survival Guide')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search hazards…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyGuideState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: [
                      for (final guide in filtered)
                        _GuideCard(guide: guide),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class EmptyGuideState extends StatelessWidget {
  const EmptyGuideState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No hazards match your search.'),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.guide});

  final HazardGuide guide;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.typeColor(guide.type ?? DisasterType.storm);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GuideDetailScreen(guide: guide),
            ),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(guide.icon, color: color, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guide.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        guide.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GuideDetailScreen extends StatelessWidget {
  const GuideDetailScreen({super.key, required this.guide});

  final HazardGuide guide;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.typeColor(guide.type ?? DisasterType.storm);
    return Scaffold(
      appBar: AppBar(
        title: Text(guide.title),
        backgroundColor: color.withValues(alpha: 0.18),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            guide.subtitle,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          _GuideSection(
            icon: Icons.verified_outlined,
            title: 'Before',
            color: AppTheme.safe,
            steps: guide.before,
          ),
          _GuideSection(
            icon: Icons.crisis_alert_outlined,
            title: 'During',
            color: AppTheme.warningA,
            steps: guide.during,
          ),
          _GuideSection(
            icon: Icons.check_circle_outline,
            title: 'After',
            color: AppTheme.info,
            steps: guide.after,
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.icon,
    required this.title,
    required this.color,
    required this.steps,
  });

  final IconData icon;
  final String title;
  final Color color;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final step in steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: _Dot(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(step, style: const TextStyle(height: 1.35)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}