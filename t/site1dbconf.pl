{
   tables => {
         ngword => "CREATE TABLE `ngword_tbl` (`word` varchar(255) NOT NULL COMMENT 'NGワードリスト',PRIMARY KEY (`word`)) ENGINE=InnoDB DEFAULT CHARSET=utf8",
         signup_tbl => "CREATE TABLE `signup_tbl` (`email` char(255) NOT NULL,`sessionid` text NOT NULL,`checkdate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,`time` int(11) NOT NULL COMMENT 'ダミー書き込み(time)',UNIQUE KEY `email` (`email`)) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='ユーザ登録テーブル'",
         uploadfile_tbl =>  "CREATE TABLE `uploadfile_tbl` (`filename` varchar(255) NOT NULL,`data` longblob NOT NULL,`uid` char(25) NOT NULL,`mime` char(255) NOT NULL,`datetime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,`comment` text,KEY `uid` (`uid`)) ENGINE=InnoDB DEFAULT CHARSET=utf8",
         user_tbl => "CREATE TABLE `user_tbl` (`email` char(255) NOT NULL,`username` varchar(255) NOT NULL,`password` char(255) NOT NULL,`uid` char(25) NOT NULL,`makedate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,UNIQUE KEY `email` (`email`),KEY `uid` (`uid`)) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='ユーザー情報'",
             }
}
