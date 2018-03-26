require 'puppet/util/windows'

module Puppet::Util::Windows::String
  extend ::FFI::Library

  def wide_string(str)
    # if given a nil string, assume caller wants to pass a nil pointer to win32
    return nil if str.nil?
    # ruby (< 2.1) does not respect multibyte terminators, so it is possible
    # for a string to contain a single trailing null byte, followed by garbage
    # causing buffer overruns.
    #
    # See http://svn.ruby-lang.org/cgi-bin/viewvc.cgi?revision=41920&view=revision
    newstr = str + "\0".encode(str.encoding)
    newstr.encode!('UTF-16LE')
  end
  module_function :wide_string

  # https://msdn.microsoft.com/en-us/library/windows/desktop/dd317756(v=vs.85).aspx
  #
  # NOTE: A dummy encoding is an encoding for which character handling is not
  # properly implemented. It is used for stateful encodings.
  #
  # From https://www.debian.org/doc/manuals/intro-i18n/ch-coding.en.html
  #
  # 3.2 Stateless and Stateful
  #
  # To construct an encoding with two or more CCS, CES has to supply a method to
  # avoid collision between these CCS. There are two ways to do that. One is to
  # make all characters in the all CCS have unique code points. The other is to
  # allow characters from different CCS to have the same code point and to have
  # a code such as escape sequence to switch SHIFT STATE, that is, to select one
  # character set.
  # An encoding with shift states is called STATEFUL and one without shift
  # states is called STATELESS.
  CODEPAGE_MAP = {
    # 037 IBM037  IBM EBCDIC US-Canada
    # NOTE: 'IBM037' and 'ebcdic-cp-us' / <Encoding:IBM037 (dummy)> is a "dummy" encoding in Ruby
    'IBM037'                        => 37,
    'ebcdic-cp-us'                  => 37,
    # 437 IBM437  OEM United States
    'IBM437'                        => 437,
    'CP437'                         => 437,
    # 737 ibm737  OEM Greek (formerly 437G); Greek (DOS)
    'IBM737'                        => 737,
    'CP737'                         => 737,
    # 775 ibm775  OEM Baltic; Baltic (DOS)
    'IBM775'                        => 775,
    'CP775'                         => 775,
    # 850 ibm850  OEM Multilingual Latin 1; Western European (DOS)
    'CP850'                         => 850,
    'IBM850'                        => 850,
    # 852 ibm852  OEM Latin 2; Central European (DOS)
    'CP852'                         => 852,
    # NOTE: Encoding::IBM852 != Encoding::CP852
    'IBM852'                        => 852,
    # 855 IBM855  OEM Cyrillic (primarily Russian)
    'CP855'                         => 855,
    # NOTE: Encoding::IBM855 != Encoding::CP855
    'IBM855'                        => 855,
    # 857 ibm857  OEM Turkish; Turkish (DOS)
    'IBM857'                        => 857,
    'CP857'                         => 857,
    # 860 IBM860  OEM Portuguese; Portuguese (DOS)
    'IBM860'                        => 860,
    'CP860'                         => 860,
    # 861 ibm861  OEM Icelandic; Icelandic (DOS)
    'IBM861'                        => 861,
    'CP861'                         => 861,
    # 862 DOS-862 OEM Hebrew; Hebrew (DOS)
    'IBM862'                        => 862,
    'CP862'                         => 862,
    # 863 IBM863  OEM French Canadian; French Canadian (DOS)
    'IBM863'                        => 863,
    'CP863'                         => 863,
    # 864 IBM864  OEM Arabic; Arabic (864)
    'IBM864'                        => 864,
    'CP864'                         => 864,
    # 865 IBM865  OEM Nordic; Nordic (DOS)
    'IBM865'                        => 865,
    'CP865'                         => 865,
    # 866 cp866 OEM Russian; Cyrillic (DOS)
    'IBM866'                        => 866,
    'CP866'                         => 866,
    # 869 ibm869  OEM Modern Greek; Greek, Modern (DOS)
    'IBM869'                        => 869,
    'CP869'                         => 869,

    # 874 windows-874 ANSI/OEM Thai (ISO 8859-11); Thai (Windows)
    'Windows-874'                   => 874,
    'CP874'                         => 874,
    # NOTE: Encoding::ISO8859_11 != Encoding::CP874
    'ISO-8859-11'                   => 874,
    'ISO8859-11'                    => 874, # same as above (alias)
    # NOTE: Encoding::TIS_620 != Encoding::CP874
    'TIS-620'                       => 874,

    # 932 shift_jis ANSI/OEM Japanese; Japanese (Shift-JIS)
    'Windows-31J'                   => 932,
    'CP932'                         => 932,
    'csWindows31J'                  => 932,
    'SJIS'                          => 932,
    'PCK'                           => 932,
    # NOTE: Encoding::Windows_31J != Encoding::SHIFT_JIS
    'Shift_JIS'                     => 932,
    # NOTE: SJIS-KDDI matches 932 for some character ranges, but its not exact
    'SJIS-KDDI'                     => 932,

    # 936 gb2312  ANSI/OEM Simplified Chinese (PRC, Singapore); Chinese Simplified (GB2312)
    'GBK'                           => 936,
    'CP936'                         => 936,
    # 949 ks_c_5601-1987  ANSI/OEM Korean (Unified Hangul Code)
    'CP949'                         => 949,

    # 950 big5  ANSI/OEM Traditional Chinese (Taiwan; Hong Kong SAR, PRC); Chinese Traditional (Big5)
    'CP950'                         => 950,
    # NOTE: Encoding::CP950 != Encoding::Big5
    'Big5'                          => 950,
    # http://www.firstobject.com/character-set-name-alias-code-page.htm lists Big5 / Big5-HKCS as the same
    'Big5-HKSCS'                    => 950, #
    'Big5-HKSCS:2008'               => 950, # same as above (alias)

    # 1200  utf-16  Unicode UTF-16, little endian byte order (BMP of ISO 10646); available only to managed applications
    # NOTE: 'UTF-16' / <Encoding:UTF-16 (dummy)> is a "dummy" encoding in Ruby
    'UTF-16'                        => 1200,
    # NOTE: Encoding::UTF_16 != Encoding::UTF_16LE
    # NOTE: UTF-16 encoding adds a \uFEFF BOM to the string, unlike UTF-16LE
    'UTF-16LE'                      => 1200,
    # 1201  unicodeFFFE Unicode UTF-16, big endian byte order; available only to managed applications
    'UTF-16BE'                      => 1201,
    'UCS-2BE'                       => 1201,
    # 1250  windows-1250  ANSI Central European; Central European (Windows)
    'Windows-1250'                  => 1250,
    'CP1250'                        => 1250,
    # 1251  windows-1251  ANSI Cyrillic; Cyrillic (Windows)
    'Windows-1251'                  => 1251,
    'CP1251'                        => 1251,
    # 1252  windows-1252  ANSI Latin 1; Western European (Windows)
    'Windows-1252'                  => 1252,
    'CP1252'                        => 1252,
    # 1253  windows-1253  ANSI Greek; Greek (Windows)
    'Windows-1253'                  => 1253,
    'CP1253'                        => 1253,
    # 1254  windows-1254  ANSI Turkish; Turkish (Windows)
    'Windows-1254'                  => 1254,
    'CP1254'                        => 1254,
    # 1255  windows-1255  ANSI Hebrew; Hebrew (Windows)
    'Windows-1255'                  => 1255,
    'CP1255'                        => 1255,
    # 1256  windows-1256  ANSI Arabic; Arabic (Windows)
    'Windows-1256'                  => 1256,
    'CP1256'                        => 1256,
    # 1257  windows-1257  ANSI Baltic; Baltic (Windows)
    'Windows-1257'                  => 1257,
    'CP1257'                        => 1257,
    # 1258  windows-1258  ANSI/OEM Vietnamese; Vietnamese (Windows)
    'Windows-1258'                  => 1258,
    'CP1258'                        => 1258,
    # 10000 macintosh MAC Roman; Western European (Mac)
    'macRoman'                      => 10000,
    # 10001 x-mac-japanese  Japanese (Mac)
    'MacJapanese'                   => 10001,
    'MacJapan'                      => 10001,
    # 10006 x-mac-greek Greek (Mac)
    'macGreek'                      => 10006,
    # 10007 x-mac-cyrillic  Cyrillic (Mac)
    'macCyrillic'                   => 10007,
    # 10010 x-mac-romanian  Romanian (Mac)
    'macRomania'                    => 10010,
    # 10017 x-mac-ukrainian Ukrainian (Mac)
    'macUkraine'                    => 10017,
    # 10021 x-mac-thai  Thai (Mac)
    'macThai'                       => 10021,
    # 10029 x-mac-ce  MAC Latin 2; Central European (Mac)
    'macCentEuro'                   => 10029,
    # 10079 x-mac-icelandic Icelandic (Mac)
    'macIceland'                    => 10079,
    # 10081 x-mac-turkish Turkish (Mac)
    'macTurkish'                    => 10081,
    # 10082 x-mac-croatian  Croatian (Mac)
    'macCroatian'                   => 10082,
    # 12000 utf-32  Unicode UTF-32, little endian byte order; available only to managed applications
    # NOTE: 'UTF-32' / <Encoding:UTF-32 (dummy)> is a "dummy" encoding in Ruby
    'UTF-32'                        => 12000,
    # NOTE: Encoding::UTF_32 != Encoding::UTF_32LE
    # NOTE: UTF-32 encoding adds a \uFEFF BOM to the string, unlike UTF-32LE
    'UTF-32LE'                      => 12000,
    'UCS-4LE'                       => 12000, # same as above (alias)
    # 12001 utf-32BE  Unicode UTF-32, big endian byte order; available only to managed applications
    'UTF-32BE'                      => 12001,
    'UCS-4BE'                       => 12001,
    # 20127 us-ascii  US-ASCII (7-bit)
    'US-ASCII'                      => 20127,
    'ASCII'                         => 20127,
    'ANSI_X3.4-1968'                => 20127,
    '646'                           => 20127,
    # 20866 koi8-r  Russian (KOI8-R); Cyrillic (KOI8-R)
    'KOI8-R'                        => 20866,
    'CP878'                         => 20866,
    # 20932 EUC-JP  Japanese (JIS 0208-1990 and 0212-1990)
    # TODO: anything here? or unused?

    # 21866 koi8-u  Ukrainian (KOI8-U); Cyrillic (KOI8-U)
    'KOI8-U'                        => 21866,
    # 28591 iso-8859-1  ISO 8859-1 Latin 1; Western European (ISO)
    'ISO8859-1'                     => 28591,
    'ISO-8859-1'                    => 28591,
    # 28592 iso-8859-2  ISO 8859-2 Central European; Central European (ISO)
    'ISO-8859-2'                    => 28592,
    'ISO8859-2'                     => 28592,
    # 28593 iso-8859-3  ISO 8859-3 Latin 3
    'ISO-8859-3'                    => 28593,
    'ISO8859-3'                     => 28593,
    # 28594 iso-8859-4  ISO 8859-4 Baltic
    'ISO-8859-4'                    => 28594,
    'ISO8859-4'                     => 28594,
    # 28595 iso-8859-5  ISO 8859-5 Cyrillic
    'ISO-8859-5'                    => 28595,
    'ISO8859-5'                     => 28595,
    # 28596 iso-8859-6  ISO 8859-6 Arabic
    'ISO-8859-6'                    => 28596,
    'ISO8859-6'                     => 28596,
    # 28597 iso-8859-7  ISO 8859-7 Greek
    'ISO-8859-7'                    => 28597,
    'ISO8859-7'                     => 28597,
    # 28598 iso-8859-8  ISO 8859-8 Hebrew; Hebrew (ISO-Visual)
    'ISO-8859-8'                    => 28598,
    'ISO8859-8'                     => 28598,
    # 28599 iso-8859-9  ISO 8859-9 Turkish
    'ISO-8859-9'                    => 28599,
    'ISO8859-9'                     => 28599,
    # 28603 iso-8859-13 ISO 8859-13 Estonian
    'ISO-8859-13'                   => 28603,
    'ISO8859-13'                    => 28603,
    # 28605 iso-8859-15 ISO 8859-15 Latin 9
    'ISO-8859-15'                   => 28605,
    'ISO8859-15'                    => 28605,

    # TODO: http://www.fileformat.info/info/charset/ISO-2022-JP/list.htm character list for ISO-2022-JP
    # TODO: finish these mappings - figure out 50220 vs 50221 vs 50222
    # TODO: when converting to ISO_2022_JP from UTF_8 it does the following:
    # UTF_8 -> EUC-JP -> stateless-ISO-2022-JP -> ISO-2022-JP
    # 50220 iso-2022-jp ISO 2022 Japanese with no halfwidth Katakana; Japanese (JIS)
    # Japanese (JIS)  50220 / iso-2022-jp
    # TODO: 'CP50220' / <Encoding:CP50220 (dummy)> is a "dummy" encoding in Ruby
    'CP50220'                       => 50220, # 'iso-2022-jp'
    # assume that the 2 below are 50220 and not 50222 or 50221
    # TODO: 'ISO-2022-JP' 'ISO2022-JP' / <Encoding:ISO-2022-JP (dummy)> is a "dummy" encoding in Ruby
    'ISO-2022-JP'                   => 50220,
    'ISO2022-JP'                    => 50220,
    # special email encoding in Japan - for the sake of mapping encodings to Windows, treat as 50220
    # http://stackoverflow.com/questions/13719183/japanese-encoding-iso2022jp-variants-for-email-communication
    # TODO: 'ISO-2022-JP2' 'ISO2022-JP2' / <Encoding:ISO-2022-JP-2 (dummy)> is a "dummy" encoding in Ruby
    'ISO-2022-JP-2'                 => 50220,
    'ISO2022-JP2'                   => 50220,
    # TODO: 'ISO-2022-JP-KDDI' / <Encoding:ISO-2022-JP-KDDI (dummy)> is a "dummy" encoding in Ruby
    'ISO-2022-JP-KDDI'              => 50220, # TODO: or 50221 ...

    # 50221 csISO2022JP ISO 2022 Japanese with halfwidth Katakana; Japanese (JIS-Allow 1 byte Kana)
    # csISO2022JP, _iso-2022-jp, CP50221, ISO-2022-JP-MS, ISO2022-JP-MS, MS50221, WINDOWS-50221
    # TODO: 'CP50221' / <Encoding:CP50221 (dummy)> is a "dummy" encoding in Ruby
    'CP50221'                       => 50221, # 'csISO2022JP'
    # From https://msdn.microsoft.com/en-us/library/system.text.encoding.getencodings(v=vs.110).aspx
    # Encodings 50220 and 50222 are both associated with the name "iso-2022-jp",
    # but they are not identical. Encoding 50220 converts half-width Katakana characters to full-width
    # Katakana characters, whereas encoding 50222 uses a shift-in/shift-out sequence to encode half-width
    # Katakana characters. The display name for encoding 50222 is "Japanese (JIS-Allow 1 byte Kana - SO/SI)"
    # to distinguish it from encoding 50220, which has the display name "Japanese (JIS)".
    # 50222 iso-2022-jp ISO 2022 Japanese JIS X 0201-1989; Japanese (JIS-Allow 1 byte Kana - SO/SI)

    # 51932 euc-jp  EUC Japanese
    'CP51932'                       => 51932,
    # NOTE: Encoding::EUCJP_MS != Encoding::CP51932
    # TODO: there is a EUC-JP as 'EUC-JP' / 20932 AND a 'euc-jp' / 51932 - make sure these are right
    # http://www.firstobject.com/character-set-name-alias-code-page.htm maps euc-jp to 20932 / not 51932
    'eucJP-ms'                      => 51932,
    'euc-jp-ms'                     => 51932,
    # TODO: there is a EUC-JP as 'EUC-JP' / 20932 AND a 'euc-jp' / 51932 - make sure these are right
    # http://www.firstobject.com/character-set-name-alias-code-page.htm maps euc-jp to 20932 / not 51932
    'EUC-JP'                        => 51932,
    'eucJP'                         => 51932,
    # https://en.wikipedia.org/wiki/JIS_X_0213
    # similar to 923 / ISO-2022-JP, but not the same - defines mappings to Unicode 10646
    'EUC-JIS-2004'                  => 51932, # extension of
    'EUC-JISX0213'                  => 51932, # same as above (alias)

    # 51936 EUC-CN  EUC Simplified Chinese; Chinese Simplified (EUC)
    'GB2312'                        => 51936,
    'EUC-CN'                        => 51936,
    'eucCN'                         => 51936,
    # https://en.wikipedia.org/wiki/GB_2312
    # HACK: GB12345 is closely related to GB2312 but not the same thing - for the sake of CP lookups, treat it the same
    'GB12345'                       => 51936,

    # 51949 euc-kr  EUC Korean
    'EUC-KR'                        => 51949,
    'eucKR'                         => 51949,
    # 54936 GB18030 Windows XP and later: GB18030 Simplified Chinese (4 byte); Chinese Simplified (GB18030)
    'GB18030'                       => 54936,
    # 65000 utf-7 Unicode (UTF-7)
    # TODO: 'UTF-7' 'CP65000' / <Encoding:UTF-7 (dummy)> is a "dummy" encoding in Ruby
    'UTF-7'                         => 65000,
    'CP65000'                       => 65000,
    # 65001 utf-8 Unicode (UTF-8)
    'UTF-8'                         => 65001,
    'CP65001'                       => 65001,
    # this appears to be UTF-8
    'UTF8-KDDI'                     => 65001,
    # HACK: not sure difference, but appear to be UTF-8
    'UTF-8-MAC'                     => 65001, # should never appear on Windows - values correct?
    'UTF8-MAC'                      => 65001, # same as above (alias)
    'UTF-8-HFS'                     => 65001, # same as above (alias)
    'UTF8-DoCoMo'                   => 65001,
    'UTF8-SoftBank'                 => 65001,

    ##
    ##  TODO: definitively figure out the following
    ##

    'SJIS-DoCoMo'                   => nil,
    'SJIS-SoftBank'                 => nil,

    ##
    ##  Ruby encodings that don't have Windows support and should never be used
    ##

    # NOTE: Windows has no binary codepage
    'ASCII-8BIT'                    => nil,
    'BINARY'                        => nil, # same as above (alias)

    # Really weird Big5 Encoding
    'Big5-UAO'                      => nil,

    # this is a weird Multilingual Environment internal encoding used for Emacs buffers
    # should never show up on Windows
    'Emacs-Mule'                    => nil,

    # From https://en.wikipedia.org/wiki/Extended_Unix_Code#EUC-TW :
    # EUC-TW is a variable-width encoding that supports US-ASCII and 16 planes of CNS 11643, each of which is 94x94.
    # It is a rarely used encoding for traditional Chinese characters as used on Taiwan. Big5 is much more common.
    'EUC-TW'                        => nil,
    'eucTW'                         => nil, # same as above (alias)

    # https://en.wikipedia.org/wiki/ISO/IEC_8859-10
    # similar to ISO-8859-1 with some changes
    # ISO-8859-10, iso-ir-157, l6, ISO_8859-10:1992, csISOLatin6, latin6
    'ISO-8859-10'                   => nil,
    'ISO8859-10'                    => nil, # same as above (alias)

    # https://en.wikipedia.org/wiki/ISO/IEC_8859-14
    # similar to ISO-8859-1 with some changes for Celtic languages
    # ISO-8859-14, iso-ir-199, ISO_8859-14:1998, ISO_8859-14, latin8, iso-celtic, l8
    'ISO-8859-14'                   => nil,
    'ISO8859-14'                    => nil, # same as above (alias)

    # https://en.wikipedia.org/wiki/ISO/IEC_8859-16
    # similar to ISO-8859-1 with some changes for South Eastern European
    # ISO-8859-16, iso-ir-226, ISO_8859-16:2001, ISO_8859-16, latin10, l10
    'ISO-8859-16'                   => nil,
    'ISO8859-16'                    => nil, # same as above (alias)

    # https://tools.ietf.org/rfc/rfc1922.txt
    # HACK: The GB 1988-89 character set is identical to ISO 646 [ISO-646] except for currency symbol and tilde
    # GB_1988-80, iso-ir-57, cn, ISO646-CN, csISO57GB1988
    'GB1988'                        => nil,

    # https://en.wikipedia.org/wiki/Code_page_951
    # Code page 949 is a superset of this code page
    # The "new" code page is a replacement for CP950 with Unicode mappings for
    # some Extended User-defined Characters (EUDC) found in HKSCS
    'CP951'                         => nil,

    # NOTE: anything "stateless" cannot use a "stateful" (dummy) encoding
    # NOTE: these multibyte encodings are closest to CP59132, but have an extra byte prefix
    'stateless-ISO-2022-JP'         => nil,
    'stateless-ISO-2022-JP-KDDI'    => nil,
  }

  ##
  ##  Windows codepages without equivalents in Ruby
  ##
  #
  # Identifier  .NET Name Additional information
  # 500 IBM500  IBM EBCDIC International
  # 708 ASMO-708  Arabic (ASMO 708)
  # 709   Arabic (ASMO-449+, BCON V4)
  # 710   Arabic - Transparent Arabic
  # 720 DOS-720 Arabic (Transparent ASMO); Arabic (DOS)
  # 858 IBM00858  OEM Multilingual Latin 1 + Euro symbol
  # 870 IBM870  IBM EBCDIC Multilingual/ROECE (Latin 2); IBM EBCDIC Multilingual Latin 2
  # 875 cp875 IBM EBCDIC Greek Modern
  # 1026  IBM1026 IBM EBCDIC Turkish (Latin 5)
  # 1047  IBM01047  IBM EBCDIC Latin 1/Open System
  # 1140  IBM01140  IBM EBCDIC US-Canada (037 + Euro symbol); IBM EBCDIC (US-Canada-Euro)
  # 1141  IBM01141  IBM EBCDIC Germany (20273 + Euro symbol); IBM EBCDIC (Germany-Euro)
  # 1142  IBM01142  IBM EBCDIC Denmark-Norway (20277 + Euro symbol); IBM EBCDIC (Denmark-Norway-Euro)
  # 1143  IBM01143  IBM EBCDIC Finland-Sweden (20278 + Euro symbol); IBM EBCDIC (Finland-Sweden-Euro)
  # 1144  IBM01144  IBM EBCDIC Italy (20280 + Euro symbol); IBM EBCDIC (Italy-Euro)
  # 1145  IBM01145  IBM EBCDIC Latin America-Spain (20284 + Euro symbol); IBM EBCDIC (Spain-Euro)
  # 1146  IBM01146  IBM EBCDIC United Kingdom (20285 + Euro symbol); IBM EBCDIC (UK-Euro)
  # 1147  IBM01147  IBM EBCDIC France (20297 + Euro symbol); IBM EBCDIC (France-Euro)
  # 1148  IBM01148  IBM EBCDIC International (500 + Euro symbol); IBM EBCDIC (International-Euro)
  # 1149  IBM01149  IBM EBCDIC Icelandic (20871 + Euro symbol); IBM EBCDIC (Icelandic-Euro)
  # 1361  Johab Korean (Johab)
  # 10002 x-mac-chinesetrad MAC Traditional Chinese (Big5); Chinese Traditional (Mac)
  # 10003 x-mac-korean  Korean (Mac)
  # 10004 x-mac-arabic  Arabic (Mac)
  # 10005 x-mac-hebrew  Hebrew (Mac)
  # 10008 x-mac-chinesesimp MAC Simplified Chinese (GB 2312); Chinese Simplified (Mac)
  # 20000 x-Chinese_CNS CNS Taiwan; Chinese Traditional (CNS)
  # 20001 x-cp20001 TCA Taiwan
  # 20002 x_Chinese-Eten  Eten Taiwan; Chinese Traditional (Eten)
  # 20003 x-cp20003 IBM5550 Taiwan
  # 20004 x-cp20004 TeleText Taiwan
  # 20005 x-cp20005 Wang Taiwan
  # 20105 x-IA5 IA5 (IRV International Alphabet No. 5, 7-bit); Western European (IA5)
  # 20106 x-IA5-German  IA5 German (7-bit)
  # 20107 x-IA5-Swedish IA5 Swedish (7-bit)
  # 20108 x-IA5-Norwegian IA5 Norwegian (7-bit)
  # 20261 x-cp20261 T.61
  # 20269 x-cp20269 ISO 6937 Non-Spacing Accent
  # 20273 IBM273  IBM EBCDIC Germany
  # 20277 IBM277  IBM EBCDIC Denmark-Norway
  # 20278 IBM278  IBM EBCDIC Finland-Sweden
  # 20280 IBM280  IBM EBCDIC Italy
  # 20284 IBM284  IBM EBCDIC Latin America-Spain
  # 20285 IBM285  IBM EBCDIC United Kingdom
  # 20290 IBM290  IBM EBCDIC Japanese Katakana Extended
  # 20297 IBM297  IBM EBCDIC France
  # 20420 IBM420  IBM EBCDIC Arabic
  # 20423 IBM423  IBM EBCDIC Greek
  # 20424 IBM424  IBM EBCDIC Hebrew
  # 20833 x-EBCDIC-KoreanExtended IBM EBCDIC Korean Extended
  # 20838 IBM-Thai  IBM EBCDIC Thai
  # 20871 IBM871  IBM EBCDIC Icelandic
  # 20880 IBM880  IBM EBCDIC Cyrillic Russian
  # 20905 IBM905  IBM EBCDIC Turkish
  # 20924 IBM00924  IBM EBCDIC Latin 1/Open System (1047 + Euro symbol)
  # 20936 x-cp20936 Simplified Chinese (GB2312); Chinese Simplified (GB2312-80)
  # 20949 x-cp20949 Korean Wansung
  # 21025 cp1025  IBM EBCDIC Cyrillic Serbian-Bulgarian
  # 21027   (deprecated)
  # 29001 x-Europa  Europa 3
  # 38598 iso-8859-8-i  ISO 8859-8 Hebrew; Hebrew (ISO-Logical)
  # 50225 iso-2022-kr ISO 2022 Korean
  # 50227 x-cp50227 ISO 2022 Simplified Chinese; Chinese Simplified (ISO 2022)
  # 50229   ISO 2022 Traditional Chinese
  # 50930   EBCDIC Japanese (Katakana) Extended
  # 50931   EBCDIC US-Canada and Japanese
  # 50933   EBCDIC Korean Extended and Korean
  # 50935   EBCDIC Simplified Chinese Extended and Simplified Chinese
  # 50936   EBCDIC Simplified Chinese
  # 50937   EBCDIC US-Canada and Traditional Chinese
  # 50939   EBCDIC Japanese (Latin) Extended and Japanese
  # 51950   EUC Traditional Chinese
  # 52936 hz-gb-2312  HZ-GB2312 Simplified Chinese; Chinese Simplified (HZ)
  # 57002 x-iscii-de  ISCII Devanagari
  # 57003 x-iscii-be  ISCII Bangla
  # 57004 x-iscii-ta  ISCII Tamil
  # 57005 x-iscii-te  ISCII Telugu
  # 57006 x-iscii-as  ISCII Assamese
  # 57007 x-iscii-or  ISCII Odia
  # 57008 x-iscii-ka  ISCII Kannada
  # 57009 x-iscii-ma  ISCII Malayalam
  # 57010 x-iscii-gu  ISCII Gujarati
  # 57011 x-iscii-pa  ISCII Punjabi

  # taken from winnls.h
  MAX_DEFAULTCHAR = 2
  MAX_LEADBYTES = 12

  # TODO: look up special aliases?
  # These names may be in the map but they're aliased to other things
  # for instance Encoding.default_external.names
  # def get_special_codepage(name)
  #   Encoding.find(Encoding.aliases['locale'])
  #   Encoding.find(Encoding.aliases['external'])
  #   Encoding.find(Encoding.aliases['internal'])
  #   Encoding.find(Encoding.aliases['filesystem'])
  # end

  def get_CP_info(encoding, &block)
    # TODO: case insensitive / barf if name not found
    # TODO: ensure encoding is a Ruby encoding object
    Encoding.names.first
    id = CODEPAGE_MAP[encoding.name]

    FFI::MemoryPointer.new(CPINFO.size) do |cpinfo_ptr|

      if GetCPInfo(id, cpinfo_ptr) == FFI::WIN32_FALSE
        raise Puppet::Util::Windows::Error.new("Failed to retrieve codepage info for #{name} / #{id}")
      end

      yield CPINFO.new(cpinfo_ptr)
    end

    # cpinfo_ptr has already been freed, nothing to return
    nil
  end
  module_function :get_CP_info

  # require 'pry'; binding.pry
  # UINT and UINT32 are the same
  # since api_types hasn't loaded yet, we must use :uchar instead of :byte
  # https://msdn.microsoft.com/en-us/library/windows/desktop/dd317780(v=vs.85).aspx
  # typedef struct _cpinfo {
  #   UINT MaxCharSize;
  #   BYTE DefaultChar[MAX_DEFAULTCHAR];
  #   BYTE LeadByte[MAX_LEADBYTES];
  # } CPINFO, *LPCPINFO;
  class CPINFO < FFI::Struct
    layout :MaxCharSize, :uint32,
           :DefaultChar, [:uchar, MAX_DEFAULTCHAR],
           :LeadByte, [:uchar, MAX_LEADBYTES]
  end

  private
  ffi_convention :stdcall

  # https://msdn.microsoft.com/en-us/library/windows/desktop/dd318078(v=vs.85).aspx
  # BOOL GetCPInfo(
  #   _In_  UINT     CodePage,
  #   _Out_ LPCPINFO lpCPInfo
  # );
  # similarly cannot use :win32_bool and must use :int32
  ffi_lib :kernel32
  attach_function :GetCPInfo, [:uint32, CPINFO], :int32
end
