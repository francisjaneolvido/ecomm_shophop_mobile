import 'package:flutter/material.dart';

/// Maps the web category icon keys without duplicating category names or order.
IconData buyerCategoryIcon(String key) => switch (key) {
  'paw-print' => Icons.pets_outlined,
  'smartphone' => Icons.smartphone_outlined,
  'shirt' => Icons.checkroom_outlined,
  'baby' => Icons.child_care_outlined,
  'sofa' => Icons.weekend_outlined,
  'dumbbell' => Icons.fitness_center_outlined,
  'heart-pulse' => Icons.health_and_safety_outlined,
  'book-open' => Icons.menu_book_outlined,
  'utensils' => Icons.restaurant_outlined,
  'car' => Icons.directions_car_outlined,
  'armchair' => Icons.chair_outlined,
  'gem' => Icons.diamond_outlined,
  'pencil' => Icons.draw_outlined,
  _ => Icons.shopping_bag_outlined,
};
