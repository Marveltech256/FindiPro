import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class ExploreScreen extends StatelessWidget {
	const ExploreScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return SafeArea(
			child: RefreshIndicator(
				onRefresh: () async {},
				child: ListView(
					physics: const AlwaysScrollableScrollPhysics(),
					padding: const EdgeInsets.all(20),
					children: [
						Row(
							children: [
								CircleAvatar(
									radius: 24,
									backgroundColor: AppTheme.skyBlue.withOpacity(0.15),
									child: const Icon(Icons.person, color: AppTheme.skyBlue),
								),
								const SizedBox(width: 14),
								Expanded(
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text('Good morning',
													style: Theme.of(context).textTheme.bodyMedium),
											Text('Welcome to FindiPro',
													style: Theme.of(context).textTheme.titleLarge),
										],
									),
								),
								IconButton(
									onPressed: () {},
									icon: const Icon(Icons.notifications_none_rounded),
								),
							],
						),
						const SizedBox(height: 24),

						// Location chip
						Container(
							padding:
									const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
							decoration: BoxDecoration(
								color: Colors.white,
								borderRadius: BorderRadius.circular(18),
							),
							child: const Row(
								children: [
									Icon(Icons.location_on_rounded, color: AppTheme.teal),
									SizedBox(width: 8),
									Expanded(
										child: Text('Kampala, Uganda'),
									),
									Icon(Icons.keyboard_arrow_down_rounded),
								],
							),
						),

						const SizedBox(height: 20),

						// Search
						TextField(
							decoration: InputDecoration(
								hintText: 'Search plumbers, electricians, cleaners...',
								prefixIcon: const Icon(Icons.search),
								suffixIcon: IconButton(
									onPressed: () {},
									icon: const Icon(Icons.tune_rounded),
								),
							),
						),

						const SizedBox(height: 28),

						Row(
							mainAxisAlignment: MainAxisAlignment.spaceBetween,
							children: [
								Text('Providers near you',
										style: Theme.of(context).textTheme.titleLarge),
								TextButton(onPressed: () {}, child: const Text('See all')),
							],
						),

						const SizedBox(height: 14),

						_providerCard(
							context,
							name: 'Sarah Plumbing Services',
							category: 'Plumbing',
							distance: '2.1 km away',
							rating: '4.9',
						),

						const SizedBox(height: 16),

						_providerCard(
							context,
							name: 'Kampala Electric Experts',
							category: 'Electrical',
							distance: '3.8 km away',
							rating: '4.8',
						),

						const SizedBox(height: 28),

						Text('Popular categories',
								style: Theme.of(context).textTheme.titleLarge),

						const SizedBox(height: 14),

						Wrap(
							spacing: 12,
							runSpacing: 12,
							children: const [
								_CategoryChip(label: 'Plumbing', icon: Icons.plumbing),
								_CategoryChip(
										label: 'Electrical', icon: Icons.electrical_services),
								_CategoryChip(label: 'Cleaning', icon: Icons.cleaning_services),
								_CategoryChip(label: 'Mechanics', icon: Icons.car_repair),
								_CategoryChip(label: 'Beauty', icon: Icons.face_retouching_natural),
								_CategoryChip(label: 'Tutors', icon: Icons.school),
							],
						),

						const SizedBox(height: 32),

						Container(
							padding: const EdgeInsets.all(22),
							decoration: BoxDecoration(
								gradient: const LinearGradient(
									colors: [AppTheme.skyBlue, AppTheme.teal],
								),
								borderRadius: BorderRadius.circular(24),
							),
							child: const Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(
										'Need help urgently?',
										style: TextStyle(
											color: Colors.white,
											fontSize: 22,
											fontWeight: FontWeight.w700,
										),
									),
									SizedBox(height: 8),
									Text(
										'Find nearby emergency service providers available right now.',
										style: TextStyle(color: Colors.white),
									),
									SizedBox(height: 16),
									FilledButton(
										onPressed: null,
										child: Text('Find emergency services'),
									),
								],
							),
						),

						const SizedBox(height: 40),
					],
				),
			),
		);
	}

	Widget _providerCard(
		BuildContext context, {
		required String name,
		required String category,
		required String distance,
		required String rating,
	}) {
		return Card(
			child: InkWell(
				borderRadius: BorderRadius.circular(22),
				onTap: () {},
				child: Padding(
					padding: const EdgeInsets.all(18),
					child: Row(
						children: [
							CircleAvatar(
								radius: 32,
								backgroundColor: AppTheme.skyBlue.withOpacity(0.12),
								child: const Icon(Icons.person, color: AppTheme.skyBlue),
							),
							const SizedBox(width: 16),
							Expanded(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(name,
												style: Theme.of(context).textTheme.titleMedium),
										const SizedBox(height: 4),
										Text(category),
										const SizedBox(height: 6),
										Text(distance,
												style: const TextStyle(color: AppTheme.teal)),
									],
								),
							),
							Column(
								children: [
									Row(
										children: [
											const Icon(Icons.star_rounded,
													color: Colors.amber, size: 18),
											const SizedBox(width: 4),
											Text(rating),
										],
									),
									const SizedBox(height: 10),
									IconButton.filled(
										onPressed: () {},
										icon: const Icon(Icons.call),
									),
								],
							),
						],
					),
				),
			),
		);
	}
}

class _CategoryChip extends StatelessWidget {
	final String label;
	final IconData icon;

	const _CategoryChip({
		required this.label,
		required this.icon,
	});

	@override
	Widget build(BuildContext context) {
		return Chip(
			avatar: Icon(icon, size: 18, color: AppTheme.skyBlue),
			label: Text(label),
			padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
			shape: RoundedRectangleBorder(
				borderRadius: BorderRadius.circular(14),
			),
			backgroundColor: Colors.white,
		);
	}
}