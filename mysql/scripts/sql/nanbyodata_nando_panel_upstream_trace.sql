
DROP TABLE IF EXISTS `nanbyodata_nando_panel_upstream_trace`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `nanbyodata_nando_panel_upstream_trace` (
  `nando_id`   varchar(30) NOT NULL,
  `trace_en`   json NULL,
  `trace_ja`   json NULL,
   PRIMARY KEY  (`nando_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;;
SET character_set_client = @saved_cs_client;


