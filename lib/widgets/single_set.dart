import 'package:flutter/cupertino.dart';

class SetTrackingWidget extends StatefulWidget {
  final int setNumber;
  final String? previousWeight;
  final String? previousReps;

  const SetTrackingWidget({
    Key? key,
    required this.setNumber,
    this.previousWeight,
    this.previousReps,
  }) : super(key: key);

  @override
  _SetTrackingWidgetState createState() => _SetTrackingWidgetState();
}

class _SetTrackingWidgetState extends State<SetTrackingWidget> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController();
    _repsController = TextEditingController();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          // Set Number
          SizedBox(
            width: 8,
            child: Text(
              '${widget.setNumber}',
              style: CupertinoTheme.of(context).textTheme.textStyle,
            ),
          ),
          // Previous Lifts
          if (widget.previousWeight != null && widget.previousReps != null)
            Expanded(
              flex: 2,
              child: Text(
                '${widget.previousWeight} x ${widget.previousReps}',
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      color: CupertinoColors.systemGrey,
                    ),
              ),
            )
          else
            Spacer(flex: 2),
          // Weight Input
          Expanded(
            flex: 1,
            child: CupertinoTextField(
              controller: _weightController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              placeholder: 'Weight',
            ),
          ),
          SizedBox(width: 8),
          // Reps Input
          Expanded(
            flex: 1,
            child: CupertinoTextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              placeholder: 'Reps',
            ),
          ),
          SizedBox(width: 8),
          // Completed Checkbox
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              setState(() {
                _isCompleted = !_isCompleted;
              });
            },
            child: Icon(
              _isCompleted
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.circle,
              color: _isCompleted
                  ? CupertinoColors.activeBlue
                  : CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }
}
