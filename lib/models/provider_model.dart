class ServiceProvider {
  final String id;
  final String name;
  final String category;
  final String location;
  final double rating;
  final int reviewCount;
  final String profileImageUrl;
  final String phone;
  final String whatsapp;
  final String email;
  final String about;
  final List<String> skills;
  final String priceRange;
  final int yearsExperience;
  final bool available;

  const ServiceProvider({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.rating,
    required this.reviewCount,
    required this.profileImageUrl,
    required this.phone,
    required this.whatsapp,
    required this.email,
    required this.about,
    required this.skills,
    required this.priceRange,
    required this.yearsExperience,
    required this.available,
  });

  // Compatibility getter for existing provider card code
  String get imageUrl => profileImageUrl;
}