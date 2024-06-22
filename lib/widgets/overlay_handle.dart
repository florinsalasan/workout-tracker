// import 'package:flutter/material.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:provider/provider.dart';
// import 'package:workout_tracker/screens/workout.dart';

// // class DraggableOverlayHandle extends StatefulWidget {
// //   final Function onMinimize; // Callback function to minimize the overlay

// //   const DraggableOverlayHandle({super.key, required this.onMinimize});

// //   @override
// //   State<DraggableOverlayHandle> createState() => _DraggableOverlayHandleState();
// // }

// // class _DraggableOverlayHandleState extends State<DraggableOverlayHandle> {
// //   bool _isDragging = false;

// //   @override
// //   Widget build(BuildContext context) {
// //     return GestureDetector(
// //       onVerticalDragDown: (details) => setState(() => _isDragging = true),
// //       onVerticalDragUpdate: (details) {
// //         if (_isDragging) {
// //           final dragDistance = details.primaryDelta!;
// //           if (dragDistance < 0 &&
// //               dragDistance.abs() > context.read<WorkoutState>().dragThreshold) {
// //             widget
// //                 .onMinimize(); // Call minimize on downward drag exceeding threshold
// //           }
// //         }
// //       },
// //       onVerticalDragEnd: (_) => setState(() => _isDragging = false),
// //       child: Container(
// //         height: 50.0, // Adjust height as needed
// //         width: double.infinity, // Occupy full width
// //         color: Colors.grey[200], // Customize handle color
// //         child: Center(
// //           child: Icon(
// //             _isDragging ? Icons.arrow_upward : Icons.drag_handle,
// //             color: Colors.black,
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }

// class DraggableOverlayHandle extends StatefulWidget {
//   final Function onMinimize; // Callback function to minimize the overlay
//   final Function onUpdateHeight; // Callback function to update overlay height
//   final double initialHeight;

//   const DraggableOverlayHandle({
//     super.key,
//     required this.onMinimize,
//     required this.onUpdateHeight,
//     required this.initialHeight,
//   });

//   @override
//   State<DraggableOverlayHandle> createState() => _DraggableOverlayHandleState();
// }

// class _DraggableOverlayHandleState extends State<DraggableOverlayHandle> {
//   bool _isDragging = false;

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onVerticalDragDown: (details) => setState(() => _isDragging = true),
//       onVerticalDragUpdate: (details) {
//         if (_isDragging) {
//           final dragDistance = details.primaryDelta!;
//           final workoutState = context.read<WorkoutState>();
//           final newHeight = workoutState.isOverlayExpanded
//               ? workoutState.initialHeight - dragDistance.abs()
//               : workoutState.initialHeight + dragDistance.abs();

//           // Clamp newHeight to valid range (optional)
//           // workoutState.updateOverlayHeight(newHeight.clamp(workoutState.minHeight, workoutState.maxHeight));

//           widget.onUpdateHeight(
//               newHeight); // Call updateHeight callback with new height
//         }
//       },
//       onVerticalDragEnd: (_) => setState(() => _isDragging = false),
//       child: Container(
//         height: 50.0, // Adjust height as needed
//         width: double.infinity, // Occupy full width
//         color: Colors.grey[200], // Customize handle color
//         child: Center(
//           child: Icon(
//             _isDragging ? Icons.arrow_upward : Icons.drag_handle,
//             color: Colors.black,
//           ),
//         ),
//       ),
//     );
//   }
// }