import 'package:flutter/material.dart';
import '../category_providers_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});
  static const _categories=['Plumbing','Electrical','Cleaning','Mechanic','Painting','Gardening','Carpentry','Moving','Beauty','Construction','IT & Technology','Other'];
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:ListView(padding:const EdgeInsets.all(20),children:[
    const Text('Categories',style:TextStyle(fontSize:28,fontWeight:FontWeight.w700)),const SizedBox(height:8),const Text('Choose a service and find approved professionals.'),const SizedBox(height:20),
    GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:_categories.length,gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:14,mainAxisSpacing:14,childAspectRatio:1.25),itemBuilder:(context,index){final name=_categories[index];return InkWell(borderRadius:BorderRadius.circular(22),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CategoryProvidersScreen(category:name))),child:Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),border:Border.all(color:Colors.black12)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Container(width:52,height:52,decoration:BoxDecoration(color:const Color(0xFF06B6D4).withValues(alpha:.12),borderRadius:BorderRadius.circular(16)),child:const Icon(Icons.handyman,color:Color(0xFF06B6D4),size:28)),const SizedBox(height:10),Text(name,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w700))])));}),
  ])));
}
