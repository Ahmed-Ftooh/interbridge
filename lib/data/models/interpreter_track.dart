enum InterpreterTrack { volunteer, paid }

extension InterpreterTrackX on InterpreterTrack {
  String get label {
    switch (this) {
      case InterpreterTrack.volunteer:
        return 'Volunteer Humanitarian';
      case InterpreterTrack.paid:
        return 'Paid Medical Track';
    }
  }

  String get description {
    switch (this) {
      case InterpreterTrack.volunteer:
        return 'Flexible requests for NGOs and refugees. Build verified hours while helping communities.';
      case InterpreterTrack.paid:
        return 'Scheduled hospital and clinic calls. Requires certificates plus a weekly shift plan.';
    }
  }
}
