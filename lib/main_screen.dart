import 'package:flutter/material.dart';
import 'screens/explore/explore_screen.dart';
import 'screens/categories/categories_screen.dart';
import 'screens/messages/messages_screen.dart';
import 'screens/profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override State<MainScreen> createState() => _MainScreenState();
}
class _MainScreenState extends State<MainScreen> {
  int _index=0;
  @override Widget build(BuildContext context){
    final pages=<Widget>[const ExploreScreen(),const CategoriesScreen(),const MessagesScreen(),const ProfileScreen()];
    return Scaffold(body:IndexedStack(index:_index,children:pages),bottomNavigationBar:NavigationBar(selectedIndex:_index,onDestinationSelected:(i)=>setState(()=>_index=i),destinations:const[
      NavigationDestination(icon:Icon(Icons.explore_outlined),selectedIcon:Icon(Icons.explore),label:'Explore'),
      NavigationDestination(icon:Icon(Icons.grid_view_outlined),selectedIcon:Icon(Icons.grid_view_rounded),label:'Categories'),
      NavigationDestination(icon:Icon(Icons.chat_bubble_outline),selectedIcon:Icon(Icons.chat_bubble),label:'Messages'),
      NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person),label:'Profile'),
    ]));
  }
}
