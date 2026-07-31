import '../../models/food_item.dart';
import '../../models/restaurant.dart';

class DummyData {
  static const List<Map<String, String>> categories = [
    {
      'name': 'Pizza',
      'icon': 'https://cdn-icons-png.flaticon.com/512/3595/3595454.png'
    },
    {
      'name': 'Burger',
      'icon': 'https://cdn-icons-png.flaticon.com/512/3075/3075977.png'
    },
    {
      'name': 'Roll',
      'icon': 'https://cdn-icons-png.flaticon.com/512/2276/2276840.png'
    },
    {
      'name': 'Chinese',
      'icon': 'https://cdn-icons-png.flaticon.com/512/944/944062.png'
    },
    {
      'name': 'Coffee',
      'icon': 'https://cdn-icons-png.flaticon.com/512/3097/3097100.png'
    },
    {
      'name': 'Desserts',
      'icon': 'https://cdn-icons-png.flaticon.com/512/7904/7904586.png'
    },
    {
      'name': 'Ice Cream',
      'icon': 'https://cdn-icons-png.flaticon.com/512/938/938063.png'
    },
    {
      'name': 'Cake',
      'icon': 'https://cdn-icons-png.flaticon.com/512/2682/2682448.png'
    },
    {
      'name': 'Biryani',
      'icon': 'https://cdn-icons-png.flaticon.com/512/706/706164.png'
    },
    {
      'name': 'Healthy',
      'icon': 'https://cdn-icons-png.flaticon.com/512/2921/2921822.png'
    },
  ];

  static final List<String> _pizzaImages = [
    'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1593560708920-61dd98c46a4e?w=600&auto=format&fit=crop',
  ];

  static final List<String> _burgerImages = [
    'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1550547660-d9450f859349?w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1586190848861-99aa4a171e90?w=600&auto=format&fit=crop',
  ];

  static final List<String> _rollImages = [
    'https://images.unsplash.com/photo-1626700051175-6518c4793f4f?w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1541518763669-27fef04b14ea?w=600&auto=format&fit=crop',
  ];

  static final List<String> _chineseImages = [
    'https://images.unsplash.com/photo-1585032226651-759b368d7246?w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=600&auto=format&fit=crop',
  ];

  static final List<String> _coffeeImages = [
    'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1541167760496-1628856ab772?w=600&auto=format&fit=crop',
  ];

  static final List<String> _dessertImages = [
    'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?w=600&auto=format&fit=crop',
  ];

  static final List<String> _iceCreamImages = [
    'https://images.unsplash.com/photo-1501443762994-82bd5dace89a?w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1497034825429-c343d7c6a68f?w=600&auto=format&fit=crop',
  ];

  static final List<String> _cakeImages = [
    'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1535141192574-5d4897c13636?w=600&auto=format&fit=crop',
  ];

  static final List<String> _biryaniImages = [
    'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1633945274405-b6c8069047b0?w=600&auto=format&fit=crop',
  ];

  static final List<String> _healthyImages = [
    'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop',
  ];

  static List<FoodItem> generateFoodItems(String restaurantId) {
    List<FoodItem> items = [];
    int idCounter = 1;

    // Helper map to build foods by categories
    final Map<String, List<String>> catImages = {
      'Pizza': _pizzaImages,
      'Burger': _burgerImages,
      'Roll': _rollImages,
      'Chinese': _chineseImages,
      'Coffee': _coffeeImages,
      'Desserts': _dessertImages,
      'Ice Cream': _iceCreamImages,
      'Cake': _cakeImages,
      'Biryani': _biryaniImages,
      'Healthy': _healthyImages,
    };

    // We will loop categories and create 2 items for each category
    // 10 categories * 2 items = 20 items per restaurant
    catImages.forEach((categoryName, images) {
      for (int i = 0; i < 2; i++) {
        final imgUrl = images[i % images.length];
        final isVeg = categoryName != 'Biryani' && categoryName != 'Roll' || (i == 0);
        final price = 99.0 + (idCounter * 15) % 350;
        final rating = 4.0 + (idCounter * 0.17) % 1.0;
        final name = '$categoryName Special Option $idCounter';

        items.add(FoodItem(
          id: '${restaurantId}_food_$idCounter',
          name: name,
          description: 'A delicious premium selection of $categoryName, crafted with fresh local ingredients, slow cooked to perfection and served with our custom house side sauce.',
          imageUrl: imgUrl,
          price: double.parse(price.toStringAsFixed(0)),
          rating: double.parse(rating.toStringAsFixed(1)),
          reviewCount: 30 + (idCounter * 23) % 450,
          isVeg: isVeg,
          ingredients: ['Premium Spices', 'Organic Herbs', 'Olive Oil', 'Mozzarella', 'Fresh Greens'],
          nutrition: {
            'Calories': '${200 + (idCounter * 35) % 300} kcal',
            'Protein': '${10 + (idCounter * 3) % 20}g',
            'Fat': '${5 + (idCounter * 2) % 15}g',
            'Carbs': '${30 + (idCounter * 8) % 60}g',
          },
          reviews: [
            'Absolutely amazing flavor! Must order again.',
            'Tastes fresh and very hot when delivered. Very satisfied.',
            'Decent portion size for the price.'
          ],
          category: categoryName,
        ));
        idCounter++;
      }
    });

    return items;
  }

  static List<Restaurant> getRestaurants() {
    final List<String> restaurantNames = [
      'The Pizza Palette',
      'Burger Bistro',
      'Roll Junction',
      'Golden Dragon Chinese',
      'Cafe Mocha',
      'Sweet Delights',
      'Gelato Royale',
      'The Cake Atelier',
      'Shahi Biryani Durbar',
      'Green Garden Salads',
      'Bake & Flake Bakery',
      'Pizzeria Napoli',
      'Royal Grill House',
      'Spice Symphony',
      'Fit & Fine Bowls'
    ];

    final List<String> banners = [
      'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1552566626-52f8b828add9?w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1544025162-d76694265947?w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1498654896293-37aacf113fd9?w=800&auto=format&fit=crop',
    ];

    final List<String> logos = [
      'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=150&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?w=150&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1482049016688-2d3e1b311543?w=150&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1484723091739-30a097e8f929?w=150&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=150&auto=format&fit=crop',
    ];

    final List<String> offers = [
      'Flat 50% OFF up to ₹100',
      'Buy 1 Get 1 Free',
      'Flat ₹75 OFF on ₹299+',
      'Free Delivery on orders above ₹199',
      '20% OFF with code GOLDEN',
    ];

    final List<String> distances = ['1.2 km', '2.5 km', '0.8 km', '3.1 km', '1.7 km', '4.2 km', '2.0 km', '0.5 km', '1.9 km', '2.8 km'];
    final List<String> deliveryTimes = ['15-20 mins', '25-30 mins', '30-35 mins', '20-25 mins', '10-15 mins'];

    return List.generate(15, (index) {
      final id = 'restaurant_${index + 1}';
      final name = restaurantNames[index];
      final banner = banners[index % banners.length];
      final logo = logos[index % logos.length];
      final rating = 3.9 + (index * 0.08) % 1.0;
      final distance = distances[index % distances.length];
      final deliveryTime = deliveryTimes[index % deliveryTimes.length];
      final offer = offers[index % offers.length];
      
      // Determine categories it services
      List<String> rCategories = ['Pizza', 'Burger', 'Chinese'];
      if (index % 3 == 1) {
        rCategories = ['Roll', 'Coffee', 'Desserts', 'Cake'];
      } else if (index % 3 == 2) {
        rCategories = ['Biryani', 'Healthy', 'Ice Cream'];
      }

      return Restaurant(
        id: id,
        name: name,
        bannerUrl: banner,
        logoUrl: logo,
        rating: double.parse(rating.toStringAsFixed(1)),
        ratingCount: 100 + (index * 250),
        distance: distance,
        deliveryTime: deliveryTime,
        offerText: offer,
        isOpen: index != 13, // Make one closed for realism
        categories: rCategories,
        items: generateFoodItems(id),
        isFeatured: index % 4 == 0,
      );
    });
  }
}
