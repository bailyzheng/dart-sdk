part of 'resource.dart';

class StreamResource extends Resource {
  final Stream<List<int>> extStream;
  @override
  final String id;
  StreamResource({
    required this.extStream,
    required int length,
    String? name,
    int? partSize,
  })  : id = 'stream_${extStream.hashCode}_size_$length',
        super(name: name, length: length, partSize: partSize);

  late StreamController<List<int>> _controller;
  StreamSubscription<List<int>>? sub;
  var start = 0;
  List<int> tmpData = [];
  List<int> lastLeft = [];
  var curCount = 0;
  int? firstLength;

  @override
  Future<void> close() async {
    print('stream resource enter close');
    if (status == ResourceStatus.Open) {
      if (!_controller.isClosed) {
        print('stream resource not close controller');
        // await _controller.close();
      }
    }
    return await super.close();
  }

  void sendChunkData() {
    if (tmpData.length >= chunkSize) {
      print('tmpData length is ${tmpData.length}, send length is $chunkSize');
      _controller.add(tmpData.sublist(0, chunkSize));
      lastLeft.addAll(tmpData.sublist(chunkSize));
      print('lastLeft length is ${lastLeft.length}');
    } else {
      print('last chunk, send length is ${tmpData.length}');
      _controller.add(tmpData);
    }

    print('before: start is $start');
    start += chunkSize;
    print('after: start is $start');
    // 文件读取完毕
    if (start >= length) {
      print('read finished');
      _controller.close();
    }
  }

  Future<void> onListen() async {
    print('enter onListen');
    if (sub == null) {
      print('first to subscribe');
      sub = extStream.listen((bytes) async {
        firstLength ??= bytes.length;
        tmpData.addAll(bytes);
        curCount += bytes.length;
        print('curCount is $curCount, bytes length is ${bytes.length}');
        if (bytes.length < firstLength!) {
          print('finish read, pause');
          sub?.pause();
          sendChunkData();
        } else if (curCount >= chunkSize) {
          print('exceed chunkSize, pause');
          sub?.pause();
          sendChunkData();
        }
      });
    } else if (sub?.isPaused == true) {
      print('is paused');
      tmpData.clear();
      tmpData.addAll(lastLeft);
      lastLeft.clear();
      curCount = tmpData.length;
      print('curCount init to $curCount');

      if (lastLeft.length >= chunkSize) {
        print('last left data exceed chunkSize');
        sendChunkData();
      } else if (start + lastLeft.length >= length) {
        print('last chunk, to send');
        sendChunkData();
      } else {
        print('subscribe resume');
        sub?.resume();
      }
    } else {
      print('should not be here');
    }
  }

  @override
  Stream<List<int>> createStream() {
    print('enter createStream');

    _controller = StreamController<List<int>>.broadcast(
      onListen: onListen,
    );

    return _controller.stream;
  }

  @override
  String toString() {
    return 'stream@${stream.hashCode}';
  }
}
