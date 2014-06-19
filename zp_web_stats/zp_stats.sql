SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- База данных: `zp_stats`
--

-- --------------------------------------------------------

--
-- Структура таблицы `zp_classes`
--

CREATE TABLE IF NOT EXISTS `zp_classes` (
  `id` int(10) unsigned NOT NULL,
  `name` varchar(64) NOT NULL,
  `info` varchar(64) NOT NULL,
  `hp` int(10) unsigned NOT NULL,
  `speed` int(10) unsigned NOT NULL,
  `grav` decimal(5,2) NOT NULL,
  `kb` decimal(5,2) NOT NULL,
  UNIQUE KEY `id` (`id`)
) CHARSET=utf8;

-- --------------------------------------------------------

--
-- Структура таблицы `zp_class_stats`
--

CREATE TABLE IF NOT EXISTS `zp_class_stats` (
  `id` int(10) unsigned NOT NULL,
  `id_player` int(10) unsigned NOT NULL,
  `infect` int(10) unsigned NOT NULL DEFAULT '0',
  `kills` int(10) unsigned NOT NULL DEFAULT '0',
  `death` int(10) unsigned NOT NULL DEFAULT '0',
  `games` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`,`id_player`)
) DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Структура таблицы `zp_graph`
--

CREATE TABLE IF NOT EXISTS `zp_graph` (
  `time` int(10) unsigned NOT NULL,
  `connections` int(2) unsigned NOT NULL,
  `kills` int(10) unsigned NOT NULL,
  `infects` int(10) unsigned NOT NULL,
  `damage` int(10) unsigned NOT NULL,
  PRIMARY KEY (`time`)
) DEFAULT CHARSET=latin1;

-- --------------------------------------------------------

--
-- Структура таблицы `zp_maps`
--

CREATE TABLE IF NOT EXISTS `zp_maps` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `map` varchar(32) NOT NULL,
  `zombie_win` int(11) NOT NULL DEFAULT '0',
  `human_win` int(11) NOT NULL DEFAULT '0',
  `tie` int(11) NOT NULL DEFAULT '0',
  `games` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`),
  UNIQUE KEY `map` (`map`)
) DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Структура таблицы `zp_players`
--

CREATE TABLE IF NOT EXISTS `zp_players` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `rank` int(10) unsigned NOT NULL DEFAULT '0',
  `ammo` int(10) unsigned NOT NULL DEFAULT '0',
  `nick` varchar(32) NOT NULL,
  `ip` varchar(32) NOT NULL,
  `steam_id` varchar(32) NOT NULL,
  `total_damage` int(10) unsigned NOT NULL DEFAULT '0',
  `last_join` int(10) unsigned NOT NULL DEFAULT '0',
  `last_leave` int(10) unsigned NOT NULL DEFAULT '0',
  `first_zombie` int(11) NOT NULL DEFAULT '0',
  `infect` int(11) NOT NULL DEFAULT '0',
  `zombiekills` int(11) NOT NULL DEFAULT '0',
  `humankills` int(11) NOT NULL DEFAULT '0',
  `nemkills` int(11) NOT NULL DEFAULT '0',
  `survkills` int(11) NOT NULL DEFAULT '0',
  `suicide` int(11) NOT NULL DEFAULT '0',
  `death` int(11) NOT NULL DEFAULT '0',
  `infected` int(11) NOT NULL DEFAULT '0',
  `online` int(11) NOT NULL DEFAULT '0',
  `zclass` int(10) unsigned NOT NULL DEFAULT '0',
  `hclass` int(10) unsigned NOT NULL DEFAULT '0',
  `nemesis` int(10) unsigned NOT NULL DEFAULT '0',
  `survivor` int(10) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `nick` (`nick`,`ip`,`steam_id`)
) DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Структура таблицы `zp_server_players`
--

CREATE TABLE IF NOT EXISTS `zp_server_players` (
  `id_player` int(32) unsigned NOT NULL,
  `server` varchar(25) NOT NULL,
  UNIQUE KEY `id_player` (`id_player`)
) DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Структура таблицы `zp_shoots`
--

CREATE TABLE IF NOT EXISTS `zp_shoots` (
  `id_weapon` int(10) unsigned NOT NULL,
  `id_player` int(10) unsigned NOT NULL,
  `shoot` int(10) DEFAULT '0',
  `hit_head` int(11) DEFAULT '0',
  `hit_chest` int(11) NOT NULL DEFAULT '0',
  `hit_stomach` int(11) NOT NULL DEFAULT '0',
  `hit_leftarm` int(11) NOT NULL DEFAULT '0',
  `hit_rightarm` int(11) NOT NULL DEFAULT '0',
  `hit_leftleg` int(11) NOT NULL DEFAULT '0',
  `hit_rightleg` int(11) NOT NULL DEFAULT '0',
  `hit_shield` int(11) NOT NULL DEFAULT '0',
  `kills` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id_player`,`id_weapon`)
) DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Структура таблицы `zp_weapons`
--

CREATE TABLE IF NOT EXISTS `zp_weapons` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(32) NOT NULL,
  PRIMARY KEY (`id`)
) DEFAULT CHARSET=utf8 ;

-- --------------------------------------------------------

--
-- Структура для представления `zp_class_sum_stats`
--

-- --------------------------------------------------------

CREATE VIEW `zp_class_sum_stats` AS (select `zp_class_stats`.`id` AS `id`,sum(`zp_class_stats`.`infect`) AS `infect`,sum(`zp_class_stats`.`kills`) AS `kills`,sum(`zp_class_stats`.`death`) AS `death`,sum(`zp_class_stats`.`games`) AS `games` from `zp_class_stats` group by `zp_class_stats`.`id`);




--
-- Структура для представления `zp_weapon_stat`
--

CREATE VIEW `zp_weapon_stat` AS (select `zp_shoots`.`id_weapon` AS `id_weapon`,`zp_weapons`.`name` AS `name`,sum(`zp_shoots`.`shoot`) AS `shoot`,sum(`zp_shoots`.`hit_head`) AS `hit_head`,sum(`zp_shoots`.`hit_chest`) AS `hit_chest`,sum(`zp_shoots`.`hit_stomach`) AS `hit_stomach`,sum(`zp_shoots`.`hit_leftarm`) AS `hit_leftarm`,sum(`zp_shoots`.`hit_rightarm`) AS `hit_rightarm`,sum(`zp_shoots`.`hit_leftleg`) AS `hit_leftleg`,sum(`zp_shoots`.`hit_rightleg`) AS `hit_rightleg`,sum(`zp_shoots`.`kills`) AS `kills` from (`zp_shoots` join `zp_weapons`) where (`zp_shoots`.`id_weapon` = `zp_weapons`.`id`) group by `zp_shoots`.`id_weapon`);


INSERT INTO `zp_weapons` (`id`, `name`) VALUES
(1, 'P228'),
(3, 'SCOUT'),
(4, 'HEGRENADE'),
(5, 'XM1014'),
(6, 'C4'),
(7, 'MAC10'),
(8, 'AUG'),
(9, 'SMOKEGRENADE'),
(10, 'ELITE'),
(11, 'FIVESEVEN'),
(12, 'UMP45'),
(13, 'SG550'),
(14, 'GALIL'),
(15, 'FAMAS'),
(16, 'USP'),
(17, 'GLOCK18'),
(18, 'AWP'),
(19, 'MP5NAVY'),
(20, 'M249'),
(21, 'M3'),
(22, 'M4A1'),
(23, 'TMP'),
(24, 'G3SG1'),
(25, 'FLASHBANG'),
(26, 'DEAGLE'),
(27, 'SG552'),
(28, 'AK47'),
(29, 'KNIFE'),
(30, 'P90');