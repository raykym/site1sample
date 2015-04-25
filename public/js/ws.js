$(#chatroom).on('pageshow',function () {
  $('#msg').focus();

  var log = function (text) {
    $('#log').val( $('#log').val() + text + "\n");
  };
  
  var ws = new WebSocket('wss://westwind.iobb.net/menu/chatroom/echo');
  ws.onopen = function () {
    log('Connection opened ws.js');
  };
  
  ws.onmessage = function (msg) {
    var res = JSON.parse(msg.data);
    log('[' + res.hms + '] ' + res.text); 
  };

  $('#msg').keydown(function (e) {
    if (e.keyCode == 13 && $('#msg').val()) {
        ws.send($('#msg').val());
        $('#msg').val('');
    }
  });
});
