class HomeHeroSliderModel {
  final String id;
  final String imageUrl;
  final String title;
  final String description;
  final String buttonText;
  final String actionType; // 'ORDER_NOW', 'EXPLORE_MENU', 'GRAB_DEAL'
  final String targetRestaurantId;
  final String targetBranchId;
  final bool active;
  final int order;

  const HomeHeroSliderModel({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.actionType,
    required this.targetRestaurantId,
    required this.targetBranchId,
    required this.active,
    required this.order,
  });

  factory HomeHeroSliderModel.fromMap(Map<String, dynamic> map, {String fallbackId = ''}) {
    return HomeHeroSliderModel(
      id: (map['id'] ?? fallbackId).toString(),
      imageUrl: (map['url'] ?? map['imageUrl'] ?? map['image'] ?? '').toString(),
      title: (map['title'] ?? map['content'] ?? map['name'] ?? '').toString(),
      description: (map['description'] ?? map['subtitle'] ?? '').toString(),
      buttonText: (map['buttonText'] ?? map['ctaText'] ?? map['btnText'] ?? 'Order Now').toString(),
      actionType: (map['actionType'] ?? map['buttonAction'] ?? map['action'] ?? 'ORDER_NOW').toString().toUpperCase(),
      targetRestaurantId: (map['targetRestaurantId'] ?? map['restaurantId'] ?? '').toString(),
      targetBranchId: (map['targetBranchId'] ?? map['branchId'] ?? '').toString(),
      active: map['active'] ?? map['enabled'] ?? true,
      order: (map['order'] is num) ? (map['order'] as num).toInt() : 1,
    );
  }
}

const List<HomeHeroSliderModel> kDefaultHomeHeroSliders = [
  HomeHeroSliderModel(
    id: 'hero-1',
    imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800&q=80&auto=format&fit=crop',
    title: 'FLAT 50% OFF ON FIRST ORDER',
    description: 'Taste the finest handcrafted artisanal pizzas in town',
    buttonText: 'Order Now',
    actionType: 'ORDER_NOW',
    targetRestaurantId: '',
    targetBranchId: '',
    active: true,
    order: 1,
  ),
  HomeHeroSliderModel(
    id: 'hero-2',
    imageUrl: 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=800&q=80&auto=format&fit=crop',
    title: 'FAMILY COMBO SPECIAL SAVINGS',
    description: 'Buy 2 Medium Pizzas & get 1 Garlic Bread + 2 Drinks Free',
    buttonText: 'Explore Menu',
    actionType: 'EXPLORE_MENU',
    targetRestaurantId: '',
    targetBranchId: '',
    active: true,
    order: 2,
  ),
  HomeHeroSliderModel(
    id: 'hero-3',
    imageUrl: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800&q=80&auto=format&fit=crop',
    title: 'CHEESY DELIGHT WEEKEND DEAL',
    description: 'Flat ₹100 Cashback with Reward Points on all orders',
    buttonText: 'Grab Deal',
    actionType: 'GRAB_DEAL',
    targetRestaurantId: '',
    targetBranchId: '',
    active: true,
    order: 3,
  ),
];
