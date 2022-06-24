import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import 'package:my_chat_app/models/message.dart';
import 'package:my_chat_app/utils/constants.dart';

part 'messages_state.dart';

class MessagesCubit extends Cubit<MessagesState> {
  MessagesCubit() : super(MessagesInitial());

  StreamSubscription<List<Message>>? _messagesSubscription;
  List<Message> _messages = [];

  late final String _roomId;
  late final String _myUserId;

  void setMessagesListener() {
    _myUserId = supabase.auth.user()!.id;

    _messagesSubscription = supabase
        .from('messages')
        .stream(['id'])
        .order('created_at')
        .execute()
        .map<List<Message>>(
          (data) => data
              .map<Message>(
                (row) => Message.fromMap(
                  map: row,
                  myUserId: _myUserId,
                ),
              )
              .toList(),
        )
        .listen((messages) {
          _messages = messages;
          if (_messages.isEmpty) {
            emit(MessagesEmpty());
          } else {
            emit(MessagesLoaded(_messages));
          }
        });
  }

  Future<void> sendMessage(String text) async {
    /// Add message to present to the user right away
    final message = Message(
      id: 'new',
      roomId: _roomId,
      profileId: _myUserId,
      content: text,
      createdAt: DateTime.now(),
      isMine: true,
    );
    _messages.insert(0, message);
    emit(MessagesLoaded(_messages));
    final result =
        await supabase.from('messages').insert(message.toMap()).execute();
    final error = result.error;
    if (error != null) {
      emit(MessagesError('Error submitting message.'));
      _messages.removeWhere((message) => message.id == 'new');
      emit(MessagesLoaded(_messages));
    }
  }

  @override
  Future<void> close() {
    _messagesSubscription?.cancel();
    return super.close();
  }
}
