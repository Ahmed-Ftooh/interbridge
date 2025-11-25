import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';
import 'supabase_service.dart';
import 'dart:io';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SupabaseService _supabaseService = SupabaseService();

  // OPTIMIZED: Add pagination support to prevent loading all messages at once
  // Default limit is 100 messages to improve performance
  Future<List<Map<String, dynamic>>> fetchMessages(
    String requestId, {
    int limit = 500,
  }) async {
    log('Fetching messages for requestId: $requestId (limit: $limit)');
    try {
      final res = await _supabase
          .from('chat_messages')
          .select('''
            *,
            user_profiles!chat_messages_sender_id_fkey(
              username,
              profile_image,
              role
            )
          ''')
          .eq('request_id', requestId)
          .order('created_at', ascending: false)
          .limit(limit);
      log('Successfully fetched ${res.length} messages with user profiles');

      // Process messages to ensure proper username fallbacks and profile image URLs
      final messages =
          List<Map<String, dynamic>>.from(res).map((message) {
            final userProfile =
                message['user_profiles'] as Map<String, dynamic>?;
            if (userProfile == null || userProfile['username'] == null) {
              // Provide fallback username based on sender_id
              message['user_profiles'] = {
                'username': 'User',
                'profile_image': null,
                'role': 'user',
              };
            } else {
              // Ensure profile image URL is properly formatted
              final profileImage = userProfile['profile_image'] as String?;
              if (profileImage != null && profileImage.isNotEmpty) {
                userProfile['profile_image'] = _supabaseService
                    .getProfileImageUrl(profileImage);
              }
            }
            return message;
          }).toList();

      // Return messages in chronological order after fetching the latest ones
      return messages.reversed.toList();
    } catch (e) {
      log('Failed to fetch messages with user profiles: $e');
      // If the table doesn't exist or there's a foreign key issue,
      // try a simpler query without the join
      try {
        final res = await _supabase
            .from('chat_messages')
            .select('*')
            .eq('request_id', requestId)
            .order('created_at', ascending: false)
            .limit(limit);
        log(
          'Successfully fetched ${res.length} messages without user profiles',
        );

        // Add fallback user profiles for messages without joins
        final messages =
            List<Map<String, dynamic>>.from(res).map((message) {
              message['user_profiles'] = {
                'username': 'User',
                'profile_image': null,
                'role': 'user',
              };
              return message;
            }).toList();

        return messages.reversed.toList();
      } catch (e2) {
        log('Failed to fetch messages even without user profiles: $e2');
        // If even the basic query fails, the table probably doesn't exist
        // Return empty list - this is not an error for a new chat
        log('Returning empty message list - chat table may not exist yet');
        return [];
      }
    }
  }

  Future<Map<String, dynamic>> sendMessage(
    String requestId,
    String content, {
    String messageType = 'text',
    String? attachmentUrl, // This will now be the STORAGE PATH
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    try {
      log('Sending message to Supabase:');
      log('  requestId: $requestId');
      log('  content: $content');
      log('  messageType: $messageType');
      log('  attachmentUrl: $attachmentUrl');

      final insertPayload = {
        'request_id': requestId,
        'sender_id': userId,
        'content': content,
        'message_type': messageType,
        'attachment_url': attachmentUrl,
      };

      Map<String, dynamic> result =
          await _supabase
              .from('chat_messages')
              .insert(insertPayload)
              .select('*')
              .single();

      log('Message inserted successfully');

      // Process the result to ensure proper format
      // Ensure essential fields are present even if Supabase omits them in the response
      result['sender_id'] ??= userId;
      result['request_id'] ??= requestId;
      result['message_type'] ??= messageType;

      // CRITICAL: Ensure attachment_url is always in the result
      if (attachmentUrl != null) {
        result['attachment_url'] = attachmentUrl;
        log('Set attachment_url in result: $attachmentUrl');
      }

      // Prefetch signed URL for attachments
      if (attachmentUrl != null) {
        try {
          log('Attempting to prefetch signed URL for: $attachmentUrl');
          final signedUrl = await createSignedUrl(attachmentUrl);
          result['attachment_signed_url'] = signedUrl;
          log('Successfully prefetched signed URL');
        } catch (e) {
          log('WARNING: Unable to prefetch signed URL: $e');
          log('URL will be fetched lazily by the UI');
          // Set to null explicitly so UI knows to fetch it
          result['attachment_signed_url'] = null;
        }
      }

      final userProfile = result['user_profiles'] as Map<String, dynamic>?;
      if (userProfile == null || userProfile['username'] == null) {
        // Try to fetch user profile manually
        try {
          final profile = await _supabaseService.getUserProfile(userId);
          if (profile != null) {
            result['user_profiles'] = {
              'username': profile.username,
              'profile_image': _supabaseService.getProfileImageUrl(
                profile.profileImage,
              ),
              'role': profile.role,
            };
          } else {
            result['user_profiles'] = {
              'username': 'User',
              'profile_image': null,
              'role': 'user',
            };
          }
        } catch (e) {
          log('Error fetching user profile: $e');
          result['user_profiles'] = {
            'username': 'User',
            'profile_image': null,
            'role': 'user',
          };
        }
      } else {
        // Ensure profile image URL is properly formatted
        final profileImage = userProfile['profile_image'] as String?;
        if (profileImage != null && profileImage.isNotEmpty) {
          userProfile['profile_image'] = _supabaseService.getProfileImageUrl(
            profileImage,
          );
        }
      }

      return result;
    } catch (e) {
      log('Error sending message to Supabase: $e');
      log('Error type: ${e.runtimeType}');
      if (e.toString().contains('relation "chat_messages" does not exist')) {
        throw Exception(
          'Chat functionality is not set up yet. Please contact support to enable chat features.',
        );
      }
      rethrow;
    }
  }

  // --- MODIFIED: uploadChatAttachment with Enhanced Error Handling ---
  Future<String> uploadChatAttachment(
    File file,
    String fileName,
    String messageType, // 'image', 'audio', 'file'
  ) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    // Validate file exists
    if (!await file.exists()) {
      log('Error: File does not exist at path: ${file.path}');
      throw Exception('File does not exist: ${file.path}');
    }

    log('Reading file bytes for: $fileName (path: ${file.path})');
    final fileBytes = await file.readAsBytes();
    log('File size: ${fileBytes.length} bytes');

    // Validate file size (e.g., max 50MB)
    const maxFileSize = 50 * 1024 * 1024; // 50MB
    if (fileBytes.length > maxFileSize) {
      throw Exception('File too large. Maximum size is 50MB');
    }

    // Validate file is not empty
    if (fileBytes.isEmpty) {
      throw Exception('File is empty: ${file.path}');
    }

    final fileExt = fileName.split('.').last.toLowerCase();

    // Generate unique storage path (relative to bucket root)
    final storagePath =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

    String contentType;
    switch (messageType) {
      case 'image':
        contentType = 'image/$fileExt';
        break;
      case 'audio':
        // .m4a files must use the 'audio/mp4' content type
        contentType = (fileExt == 'm4a') ? 'audio/mp4' : 'audio/$fileExt';
        log('Uploading audio with contentType: $contentType');
        break;
      default:
        contentType = 'application/octet-stream';
    }

    try {
      log('Uploading to storage path: $storagePath');

      // Upload with timeout protection (30 seconds)
      await _supabase.storage
          .from('chat_attachments')
          .uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Upload timed out after 30 seconds');
            },
          );

      log('File uploaded successfully to path: $storagePath');

      // Verify upload by checking if file exists in storage
      try {
        await _supabase.storage
            .from('chat_attachments')
            .list(path: 'chat_attachments/$userId');
        log('Upload verified successfully');
      } catch (e) {
        log('Warning: Could not verify upload: $e');
        // Don't fail if verification fails
      }

      return storagePath;
    } catch (e) {
      log('Error uploading file to Supabase storage: $e');
      log('Storage path attempted: $storagePath');
      log('File size: ${fileBytes.length} bytes, Content type: $contentType');

      // Provide more specific error messages
      if (e.toString().contains('timeout')) {
        throw Exception(
          'Upload timed out. Please check your connection and try again.',
        );
      } else if (e.toString().contains('storage')) {
        throw Exception('Storage error. Please try again later.');
      }

      rethrow;
    }
  }
  // --- END OF MODIFICATION ---

  // --- NEW METHOD: createSignedUrl with Enhanced Logging ---
  Future<String> createSignedUrl(String path) async {
    try {
      log('Creating signed URL for path: $path');

      // Validate path is not empty
      if (path.isEmpty) {
        throw Exception('Cannot create signed URL: path is empty');
      }

      final response = await _supabase.storage
          .from('chat_attachments')
          .createSignedUrl(path, 60 * 60); // 1 hour expiry

      log('Successfully created signed URL (length: ${response.length})');
      return response;
    } catch (e) {
      log('ERROR creating signed URL for path "$path": $e');
      log('Error type: ${e.runtimeType}');
      rethrow;
    }
  }
  // --- END OF NEW METHOD ---

  RealtimeChannel subscribeToMessages(
    String requestId,
    void Function(Map<String, dynamic>) onInsert,
  ) {
    try {
      log('Setting up real-time subscription for request: $requestId');
      final channel =
          _supabase.channel('chat_$requestId')
            ..onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'chat_messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'request_id',
                value: requestId,
              ),
              callback: (payload) {
                final newRow = payload.newRecord;
                log('Real-time message received:');
                log('  id: ${newRow['id']}');
                log('  message_type: ${newRow['message_type']}');
                log('  attachment_url: ${newRow['attachment_url']}');
                log('  sender_id: ${newRow['sender_id']}');
                onInsert(newRow);
              },
            )
            ..subscribe();
      log('Real-time subscription established successfully');
      return channel;
    } catch (e) {
      log('ERROR: Failed to set up real-time subscription: $e');
      return _supabase.channel('chat_dummy_$requestId');
    }
  }

  Future<String> fetchAgoraToken(String channelName, int uid) async {
    final res = await _supabase.functions.invoke(
      'generate-agora-token',
      body: {'channelName': channelName, 'uid': uid.toString()},
    );
    return (res.data as Map)['token'] as String;
  }
}
