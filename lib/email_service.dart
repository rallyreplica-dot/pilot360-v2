import 'package:resend/resend.dart';


class EmailService {
  final String apiKey;

  EmailService({required this.apiKey});

  Future<bool> sendRequestEmail({
    required String toEmail,
    required String subject,
    required String body,
  }) async {
    final resend = Resend(apiKey: apiKey);
    try {
      final result = await resend.sendEmail(
        from: 'noreply@pilot360.com',
        to: [toEmail],
        subject: subject,
        text: body,
      );
      // Log the result for debugging
      print('[DEBUG] Email sent result: '
          'to=$toEmail, subject=$subject, result=${result.toString()}');
      return true;
    } catch (e, stack) {
      // Log the error and stack trace for debugging
      print('[ERROR] Email not sent. to=$toEmail, subject=$subject');
      print('[ERROR] Exception: ${e.toString()}');
      print('[ERROR] StackTrace: $stack');
      return false;
    }
  }
}
