import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:workout_tracker/widgets/workout_overlay.dart';

// class SetTrackingWidget extends StatefulWidget {
//   final int setNumber;
//   final String? previousWeight;
//   final String? previousReps;

//   const SetTrackingWidget({
//     super.key,
//     required this.setNumber,
//     this.previousWeight,
//     this.previousReps,
//   });

//   @override
//   SetTrackingWidgetState createState() => SetTrackingWidgetState();
// }

// class SetTrackingWidgetState extends State<SetTrackingWidget> {
//   final TextEditingController weightController = TextEditingController();
//   final TextEditingController repsController = TextEditingController();
//   bool _isCompleted = false;

//   @override
//   void initState() {
//     super.initState();
//   }

//   @override
//   void dispose() {
//     weightController.dispose();
//     repsController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(26.0, 4.0, 16.0, 0),
//       child: Row(
//         children: [
//           // Set Number
//           SizedBox(
//             width: 8,
//             child: Text(
//               '${widget.setNumber}',
//               style: CupertinoTheme.of(context).textTheme.textStyle,
//             ),
//           ),
//           // Previous Lifts
//           if (widget.previousWeight != null && widget.previousReps != null)
//             Expanded(
//               flex: 2,
//               child: Text(
//                 '${widget.previousWeight} x ${widget.previousReps}',
//                 style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
//                       color: CupertinoColors.systemGrey,
//                     ),
//               ),
//             )
//           else
//             const Spacer(flex: 2),
//           // Weight Input
//           Expanded(
//             flex: 1,
//             child: CupertinoTextField(
//               controller: weightController,
//               keyboardType:
//                   const TextInputType.numberWithOptions(decimal: true),
//               placeholder: 'Weight',
//             ),
//           ),
//           const SizedBox(width: 8),
//           // Reps Input
//           Expanded(
//             flex: 1,
//             child: CupertinoTextField(
//               controller: repsController,
//               keyboardType: TextInputType.number,
//               placeholder: 'Reps',
//             ),
//           ),
//           const SizedBox(width: 8),
//           // Completed Checkbox
//           CupertinoButton(
//             padding: EdgeInsets.zero,
//             onPressed: () {
//               setState(() {
//                 _isCompleted = !_isCompleted;
//               });
//             },
//             child: Icon(
//               _isCompleted
//                   ? CupertinoIcons.check_mark_circled_solid
//                   : CupertinoIcons.circle,
//               color: _isCompleted
//                   ? CupertinoColors.activeBlue
//                   : CupertinoColors.systemGrey,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
class SetTrackingWidget extends StatefulWidget {
  final int exerciseIndex;
  final int setIndex;
  final double initialWeight;
  final int initialReps;

  const SetTrackingWidget({
    Key? key,
    required this.exerciseIndex,
    required this.setIndex,
    required this.initialWeight,
    required this.initialReps,
  }) : super(key: key);

  @override
  SetTrackingWidgetState createState() => SetTrackingWidgetState();
}

class SetTrackingWidgetState extends State<SetTrackingWidget> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    _weightController =
        TextEditingController(text: widget.initialWeight.toString());
    _repsController =
        TextEditingController(text: widget.initialReps.toString());
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Set ${widget.setIndex + 1}'),
        Expanded(
          child: CupertinoTextField(
            controller: _weightController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            placeholder: 'Weight',
            onChanged: (value) => _updateSet(context),
          ),
        ),
        Expanded(
          child: CupertinoTextField(
            controller: _repsController,
            keyboardType: TextInputType.number,
            placeholder: 'Reps',
            onChanged: (value) => _updateSet(context),
          ),
        ),
      ],
    );
  }

  void _updateSet(BuildContext context) {
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final reps = int.tryParse(_repsController.text) ?? 0;
    Provider.of<WorkoutState>(context, listen: false).updateSet(
      widget.exerciseIndex,
      widget.setIndex,
      weight,
      reps,
    );
  }
}
