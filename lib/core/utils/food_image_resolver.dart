/// Maps a food name to a shared dish-photo asset key.
///
/// One photo serves every food that resolves to the same key — a single
/// `biryani.webp` covers Chicken, Beef, and Mutton Biryani. This keeps the
/// bundled image set at ~70 files (~2 MB) instead of one photo per food.
///
/// This is the ONLY place name→image rules live. It is applied in three
/// places: at seed import, when a user saves a custom food, and in the
/// schema v19 backfill for rows that predate the `image_key` column.
///
/// Pure Dart — no Flutter imports — so it can run inside a migration and be
/// unit tested without a widget binding.
library;

/// An ordered rule: any of [keywords] appearing in a lowercased food name
/// resolves to [imageKey].
class _Rule {
  final List<String> keywords;
  final String imageKey;
  const _Rule(this.keywords, this.imageKey);
}

/// Ordered rules — FIRST MATCH WINS, so more specific dishes must come
/// before the generic ingredient they contain. `Bun Kebab` must be tested
/// before `kebab`; `Dahi Bhalay` before `dahi`; `Chana Chaat` before `chaat`.
const List<_Rule> _rules = [
  // --- Compound dishes that contain a more generic keyword ---------------
  _Rule(['halwa puri', 'halwa poori'], 'halwa_puri'),
  _Rule(['bun kebab'], 'bun_kebab'),
  _Rule(['dahi bhalay', 'dahi bhalla', 'dahi puri'], 'dahi_bhalay'),
  _Rule(['chana', 'chickpea', 'chole'], 'chana'),
  _Rule(['gol gappay', 'golgappa', 'pani puri'], 'golgappa'),
  _Rule(['spring roll'], 'spring_roll'),
  _Rule(['garlic bread'], 'garlic_bread'),
  _Rule(['cake rusk'], 'cake_rusk'),
  _Rule(['cream roll'], 'cream_roll'),
  _Rule(['french frie', 'fries', 'onion ring'], 'fries'),

  // --- Desi mains --------------------------------------------------------
  _Rule(['biryani'], 'biryani'),
  _Rule(['pulao', 'pilaf'], 'pulao'),
  _Rule(['karahi', 'kadai', 'handi'], 'karahi'),
  _Rule(['karhi'], 'karhi'),
  _Rule(['qorma', 'korma'], 'qorma'),
  _Rule(['nihari'], 'nihari'),
  _Rule(['haleem'], 'haleem'),
  _Rule(['daal', 'dal ', 'lentil'], 'daal'),
  _Rule(['keema', 'minced meat'], 'keema'),
  _Rule(['aloo gosht', 'gosht', 'mutton curry'], 'gosht'),
  _Rule(['rajma', 'kidney bean'], 'rajma'),
  _Rule(['paneer'], 'paneer'),
  _Rule(['malai boti', 'behari', 'tikka'], 'tikka'),
  _Rule(['sabzi', 'okra', 'bhindi', 'vegetable curry'], 'sabzi'),
  _Rule(['prawn', 'shrimp'], 'prawn'),
  _Rule(['fish'], 'fish'),
  _Rule(['curry'], 'gosht'),

  // --- Breads ------------------------------------------------------------
  _Rule(['paratha'], 'paratha'),
  _Rule(['naan'], 'naan'),
  _Rule(['roti', 'chapati', 'chapatti'], 'roti'),

  // --- Street food / snacks ---------------------------------------------
  _Rule(['samosa', 'kachori', 'patties'], 'samosa'),
  _Rule(['pakora', 'pakoda'], 'pakora'),
  _Rule(['shawarma', 'shawarma'], 'shawarma'),
  _Rule(['kebab', 'kabab', 'kofta'], 'kebab'),
  _Rule(['roll'], 'roll'),
  _Rule(['chaat'], 'chaat'),

  // --- Fast food ---------------------------------------------------------
  _Rule(['burger', 'zinger'], 'burger'),
  _Rule(['pizza'], 'pizza'),
  _Rule([
    'fried chicken',
    'broast',
    'drumstick',
    'chargha',
    'wings',
  ], 'fried_chicken'),
  _Rule(['nugget'], 'nuggets'),
  _Rule(['hot dog', 'hotdog'], 'hotdog'),
  _Rule(['sandwich', 'sub '], 'sandwich'),
  _Rule(['pasta', 'spaghetti', 'macaroni', 'lasagna'], 'pasta'),
  _Rule(['noodle', 'ramen', 'chow mein'], 'noodles'),
  _Rule(['taco', 'quesadilla', 'burrito'], 'taco'),

  // --- Packaged snacks ---------------------------------------------------
  _Rule([
    'chips',
    'crisps',
    'lays',
    'kurkure',
    'slanty',
    'pringles',
    'nachos',
    'cheese puff',
    'papad',
  ], 'chips'),
  _Rule(['popcorn'], 'popcorn'),
  _Rule(['namkeen', 'nimko', 'salted peanut'], 'namkeen'),
  _Rule([
    'chocolate',
    'dairy milk',
    'kitkat',
    'snickers',
    'twix',
    'bounty',
    'mars bar',
    'galaxy',
    'kinder',
  ], 'chocolate'),
  _Rule(['candy', 'toffee', 'gummy', 'lollipop'], 'candy'),
  _Rule([
    'biscuit',
    'cookie',
    'oreo',
    'sooper',
    'prince',
    'gala',
    'rusk',
  ], 'biscuit'),
  _Rule(['granola bar', 'cereal bar'], 'granola_bar'),
  _Rule(['protein bar'], 'protein_bar'),
  _Rule(['peanut butter'], 'peanut_butter'),
  _Rule(['honey'], 'honey'),
  _Rule(['trail mix', 'dried fruit'], 'trail_mix'),
  _Rule(['almond', 'cashew', 'walnut', 'pistachio', 'nuts'], 'nuts'),

  // --- Sweets & desserts -------------------------------------------------
  _Rule(['jalebi'], 'jalebi'),
  _Rule(['gulab jamun'], 'gulab_jamun'),
  _Rule(['kheer', 'rice pudding'], 'kheer'),
  _Rule(['ras malai', 'rasmalai'], 'rasmalai'),
  _Rule(['halwa'], 'halwa'),
  _Rule(['kulfi'], 'kulfi'),
  _Rule(['falooda', 'faluda'], 'falooda'),
  _Rule([
    'ice cream',
    'sundae',
    'cone',
    'gelato',
    'frozen yogurt',
  ], 'ice_cream'),
  _Rule(['brownie'], 'brownie'),
  _Rule(['donut', 'doughnut'], 'donut'),
  _Rule(['croissant'], 'croissant'),
  _Rule(['muffin', 'cupcake'], 'muffin'),
  _Rule(['cake', 'pastry'], 'cake'),

  // --- Drinks ------------------------------------------------------------
  _Rule(['milkshake', 'shake'], 'milkshake'),
  _Rule(['smoothie'], 'smoothie'),
  _Rule(['bubble tea', 'boba'], 'bubble_tea'),
  _Rule(['lassi'], 'lassi'),
  _Rule([
    'cola',
    'coke',
    'pepsi',
    'sprite',
    '7up',
    'soda',
    'fanta',
    'mountain dew',
    'soft drink',
  ], 'cola'),
  _Rule([
    'sting',
    'red bull',
    'energy drink',
    'gatorade',
    'sports drink',
  ], 'energy_drink'),
  _Rule(['juice'], 'juice'),
  _Rule(['coffee', 'latte', 'cappuccino', 'mocha', 'frappe'], 'coffee'),
  _Rule(['chai', 'doodh patti', 'tea'], 'chai'),
  _Rule(['milk'], 'milk'),

  // --- Basics ------------------------------------------------------------
  _Rule(['omelette', 'omelet', 'egg'], 'egg'),
  _Rule(['yogurt', 'yoghurt', 'dahi', 'raita'], 'yogurt'),
  _Rule(['oats', 'porridge', 'cereal'], 'oats'),
  _Rule(['salad'], 'salad'),
  _Rule(['bread', 'toast'], 'bread'),
  _Rule(['rice'], 'rice'),

  // --- Fruit -------------------------------------------------------------
  _Rule(['apple'], 'apple'),
  _Rule(['banana'], 'banana'),
  _Rule(['mango'], 'mango'),
  _Rule(['orange'], 'orange'),
  _Rule(['grape'], 'grapes'),
  _Rule(['date', 'khajoor'], 'dates'),
];

/// Resolves [foodName] to a bundled image key, or null when nothing matches.
///
/// Matching is case-insensitive substring containment against an ordered
/// rule list; the first rule that matches wins.
String? resolveImageKey(String? foodName) {
  if (foodName == null) return null;
  final name = foodName.toLowerCase().trim();
  if (name.isEmpty) return null;

  for (final rule in _rules) {
    for (final keyword in rule.keywords) {
      if (name.contains(keyword)) return rule.imageKey;
    }
  }
  return null;
}

/// Every image key the resolver can produce — used by the fetch tool to know
/// which photos to source, and by tests to assert manifest coverage.
Set<String> get allImageKeys => {for (final r in _rules) r.imageKey};
