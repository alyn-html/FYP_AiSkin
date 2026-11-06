class Recommendation {
  final String title;
  final List<String> tips;
  const Recommendation(this.title, this.tips);
}

const Map<String, Recommendation> recommendations = {
  'acne_breakout': Recommendation('Acne Breakout', [
    'Look for salicylic acid or benzoyl peroxide cleansers',
    'Avoid heavy, pore-clogging moisturizers',
    'Change pillowcases every 2-3 days',
    "Don't pick or pop — it increases scarring risk",
  ]),
  'excess_oiliness': Recommendation('Excess Oiliness', [
    'Use a gentle foaming cleanser twice daily',
    'Try niacinamide serums to help balance oil production',
    'Avoid over-washing — it can trigger more oil',
    'Use oil-free, non-comedogenic sunscreen',
  ]),
  'dryness_dehydration': Recommendation('Dryness & Dehydration', [
    'Look for hyaluronic acid and ceramide moisturizers',
    'Avoid alcohol-based toners and harsh exfoliants',
    'Apply moisturizer on slightly damp skin',
    'Consider a humidifier in dry environments',
  ]),
  'dark_circles_eye_bags': Recommendation('Dark Circles & Eye Bags', [
    'Try caffeine or vitamin K eye creams',
    'Prioritize 7-8 hours of sleep',
    'Reduce salt intake — it can worsen puffiness',
    'Cold compresses help reduce puffiness quickly',
  ]),
  'redness_rosacea': Recommendation('Redness & Rosacea', [
    'Use fragrance-free, gentle skincare products',
    'Look for centella asiatica or azelaic acid',
    'Avoid known triggers: spicy food, alcohol, heat',
    'Always wear mineral (not chemical) sunscreen',
  ]),
};