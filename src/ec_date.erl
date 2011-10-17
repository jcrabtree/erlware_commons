%% @copyright Dale Harvey
%% @doc Format dates in erlang
%%
%% Licensed under the MIT license
%%
%% This module formats erlang dates in the form {{Year, Month, Day},
%% {Hour, Minute, Second}} to printable strings, using (almost)
%% equivalent formatting rules as http://uk.php.net/date, US vs
%% European dates are disambiguated in the same way as
%% http://uk.php.net/manual/en/function.strtotime.php That is, Dates
%% in the m/d/y or d-m-y formats are disambiguated by looking at the
%% separator between the various components: if the separator is a
%% slash (/), then the American m/d/y is assumed; whereas if the
%% separator is a dash (-) or a dot (.), then the European d-m-y
%% format is assumed. To avoid potential ambiguity, it's best to use
%% ISO 8601 (YYYY-MM-DD) dates.
%%
%% erlang has no concept of timezone so the following
%% formats are not implemented: B e I O P T Z
%% formats c and r will also differ slightly
%%
%% See tests at bottom for examples
-module(ec_date).
-author("Dale Harvey <dale@hypernumbers.com>").

-export([format/1, format/2]).
-export([parse/1, parse/2]).
-export([nparse/1]).

%% These are used exclusively as guards and so the function like
%% defines make sense
-define( is_num(X), (X >= $0 andalso X =< $9) ).
-define( is_meridian(X), (X==[] orelse X==[am] orelse X==[pm]) ).
-define( is_us_sep(X), ( X==$/) ).
-define( is_world_sep(X), ( X==$-) ).

-define(GREGORIAN_SECONDS_1970, 62167219200).

-type year() :: non_neg_integer().
-type month() :: 1..12.
-type day() :: 1..31.
-type hour() :: 0..23.
-type minute() :: 0..59.
-type second() :: 0..59.
-type daynum() :: 1..7.
-type date() :: {year(),month(),day()}.
-type time() :: {hour(),minute(),second()}.
-type datetime() :: {date(),time()}.
-type now() :: {integer(),integer(),integer()}.

%%
%% EXPORTS
%%

-spec format(string()) -> string().
%% @doc format current local time as Format
format(Format) ->
    format(Format, calendar:universal_time(),[]).

-spec format(string(),datetime() | now()) -> string().
%% @doc format Date as Format
format(Format, {_,_,_}=Now) ->
    format(Format, calendar:now_to_datetime(Now), []);
format(Format, Date) ->
    format(Format, Date, []).

-spec parse(string()) -> datetime().
%% @doc parses the datetime from a string
parse(Date) ->
    do_parse(Date, calendar:universal_time(),[]).

-spec parse(string(),datetime() | now()) -> datetime().
%% @doc parses the datetime from a string
parse(Date, {_,_,_}=Now) ->
    do_parse(Date, calendar:now_to_datetime(Now), []);
parse(Date, Now) ->
    do_parse(Date, Now, []).

do_parse(Date, Now, Opts) ->
    case parse(tokenise(string:to_upper(Date), []), Now, Opts) of
        {error, bad_date} ->
            erlang:throw({?MODULE, {bad_date, Date}});
        {D1, T1} = {{Y, M, D}, {H, M1, S}}
        when is_number(Y), is_number(M),
             is_number(D), is_number(H),
             is_number(M1), is_number(S) ->
            case calendar:valid_date(D1) of
                true -> {D1, T1};
                false -> erlang:throw({?MODULE, {bad_date, Date}})
            end;
        _ -> erlang:throw({?MODULE, {bad_date, Date}})
    end.

-spec nparse(string()) -> now().
%% @doc parses the datetime from a string into 'now' format
nparse(Date) ->
    DateTime = parse(Date),
    GSeconds = calendar:datetime_to_gregorian_seconds(DateTime),
    ESeconds = GSeconds - ?GREGORIAN_SECONDS_1970,
    {ESeconds div 1000000, ESeconds rem 1000000, 0}.


%%
%% LOCAL FUNCTIONS
%%

%% Times - 21:45, 13:45:54, 13:15PM etc
parse([Hour,$:,Min,$:,Sec | PAM], {Date, _Time}, _O) when ?is_meridian(PAM) ->
    {Date, {hour(Hour, PAM), Min, Sec}};
parse([Hour,$:,Min | PAM], {Date, _Time}, _Opts) when ?is_meridian(PAM) ->
    {Date, {hour(Hour, PAM), Min, 0}};

%% Dates 23/april/1963
parse([Day,Month,Year], {_Date, Time}, _Opts) ->
    {{Year, Month, Day}, Time};
parse([Year,X,Month,X,Day], {_Date, Time}, _Opts)
  when (?is_us_sep(X) orelse ?is_world_sep(X))
       andalso Year > 31 ->
    {{Year, Month, Day}, Time};
parse([Month,X,Day,X,Year], {_Date, Time}, _Opts) when ?is_us_sep(X) ->
    {{Year, Month, Day}, Time};
parse([Day,X,Month,X,Year], {_Date, Time}, _Opts) when ?is_world_sep(X) ->
    {{Year, Month, Day}, Time};

%% Date/Times 22 Aug 2008 6:35 PM
parse([Year,X,Month,X,Day,Hour,$:,Min | PAM], _Date, _Opts)
  when ?is_meridian(PAM) andalso
       (?is_us_sep(X) orelse ?is_world_sep(X))
       andalso Year > 31 ->
    {{Year, Month, Day}, {hour(Hour, PAM), Min, 0}};
parse([Day,X,Month,X,Year,Hour,$:,Min | PAM], _Date, _Opts)
  when ?is_meridian(PAM) andalso ?is_world_sep(X) ->
    {{Year, Month, Day}, {hour(Hour, PAM), Min, 0}};
parse([Month,X,Day,X,Year,Hour,$:,Min | PAM], _Date, _Opts)
  when ?is_meridian(PAM) andalso ?is_us_sep(X) ->
    {{Year, Month, Day}, {hour(Hour, PAM), Min, 0}};

parse([Year,X,Month,X,Day,Hour,$:,Min,$:,Sec | PAM], _Now, _Opts)
  when ?is_meridian(PAM) andalso
       (?is_us_sep(X) orelse ?is_world_sep(X))
       andalso Year > 31 ->
    {{Year, Month, Day}, {hour(Hour, PAM), Min, Sec}};
parse([Month,X,Day,X,Year,Hour,$:,Min,$:,Sec | PAM], _Now, _Opts)
  when ?is_meridian(PAM) andalso ?is_us_sep(X) ->
    {{Year, Month, Day}, {hour(Hour, PAM), Min, Sec}};
parse([Day,X,Month,X,Year,Hour,$:,Min,$:,Sec | PAM], _Now, _Opts)
  when ?is_meridian(PAM) andalso ?is_world_sep(X) ->
    {{Year, Month, Day}, {hour(Hour, PAM), Min, Sec}};


parse([Day,Month,Year,Hour,$:,Min | PAM], _Now, _Opts)
  when ?is_meridian(PAM) ->
    {{Year, Month, Day}, {hour(Hour, PAM), Min, 0}};
parse([Day,Month,Year,Hour,$:,Min,$:,Sec | PAM], _Now, _Opts)
  when ?is_meridian(PAM) ->
    {{Year, Month, Day}, {hour(Hour, PAM), Min, Sec}};

parse(_Tokens, _Now, _Opts) ->
    {error, bad_date}.

tokenise([], Acc) ->
    lists:reverse(Acc);

tokenise([N1, N2, N3, N4 | Rest], Acc)
  when ?is_num(N1), ?is_num(N2), ?is_num(N3), ?is_num(N4) ->
    tokenise(Rest, [ ltoi([N1, N2, N3, N4]) | Acc]);
tokenise([N1, N2 | Rest], Acc)
  when ?is_num(N1), ?is_num(N2) ->
    tokenise(Rest, [ ltoi([N1, N2]) | Acc]);
tokenise([N1 | Rest], Acc)
  when ?is_num(N1) ->
    tokenise(Rest, [ ltoi([N1]) | Acc]);

tokenise("JANUARY"++Rest, Acc) -> tokenise(Rest, [1 | Acc]);
tokenise("JAN"++Rest, Acc) -> tokenise(Rest, [1 | Acc]);
tokenise("FEBUARY"++Rest, Acc) -> tokenise(Rest, [2 | Acc]);
tokenise("FEB"++Rest, Acc) -> tokenise(Rest, [2 | Acc]);
tokenise("MARCH"++Rest, Acc) -> tokenise(Rest, [3 | Acc]);
tokenise("MAR"++Rest, Acc) -> tokenise(Rest, [3 | Acc]);
tokenise("APRIL"++Rest, Acc) -> tokenise(Rest, [4 | Acc]);
tokenise("APR"++Rest, Acc) -> tokenise(Rest, [4 | Acc]);
tokenise("MAY"++Rest, Acc) -> tokenise(Rest, [5 | Acc]);
tokenise("JUNE"++Rest, Acc) -> tokenise(Rest, [6 | Acc]);
tokenise("JUN"++Rest, Acc) -> tokenise(Rest, [6 | Acc]);
tokenise("JULY"++Rest, Acc) -> tokenise(Rest, [7 | Acc]);
tokenise("JUL"++Rest, Acc) -> tokenise(Rest, [7 | Acc]);
tokenise("AUGUST"++Rest, Acc) -> tokenise(Rest, [8 | Acc]);
tokenise("AUG"++Rest, Acc) -> tokenise(Rest, [8 | Acc]);
tokenise("SEPTEMBER"++Rest, Acc) -> tokenise(Rest, [9 | Acc]);
tokenise("SEPT"++Rest, Acc) -> tokenise(Rest, [9 | Acc]);
tokenise("SEP"++Rest, Acc) -> tokenise(Rest, [9 | Acc]);
tokenise("OCTOBER"++Rest, Acc) -> tokenise(Rest, [10 | Acc]);
tokenise("OCT"++Rest, Acc) -> tokenise(Rest, [10 | Acc]);
tokenise("NOVEMBER"++Rest, Acc) -> tokenise(Rest, [11 | Acc]);
tokenise("NOVEM"++Rest, Acc) -> tokenise(Rest, [11 | Acc]);
tokenise("NOV"++Rest, Acc) -> tokenise(Rest, [11 | Acc]);
tokenise("DECEMBER"++Rest, Acc) -> tokenise(Rest, [12 | Acc]);
tokenise("DECEM"++Rest, Acc) -> tokenise(Rest, [12 | Acc]);
tokenise("DEC"++Rest, Acc) -> tokenise(Rest, [12 | Acc]);

tokenise([$: | Rest], Acc) -> tokenise(Rest, [ $: | Acc]);
tokenise([$/ | Rest], Acc) -> tokenise(Rest, [ $/ | Acc]);
tokenise([$- | Rest], Acc) -> tokenise(Rest, [ $- | Acc]);
tokenise("AM"++Rest, Acc) -> tokenise(Rest, [am | Acc]);
tokenise("PM"++Rest, Acc) -> tokenise(Rest, [pm | Acc]);

%% Postel's Law
%%
%% be conservative in what you do,
%% be liberal in what you accept from others.
%%
%% See RFC 793 Section 2.10 http://tools.ietf.org/html/rfc793
%%
%% Mebbies folk want to include Saturday etc in a date, nae borra
tokenise("MONDAY"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("MON"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("TUESDAY"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("TUES"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("TUE"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("WEDNESDAY"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("WEDS"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("WED"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("THURSDAY"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("THURS"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("THUR"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("THU"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("FRIDAY"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("FRI"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("SATURDAY"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("SAT"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("SUNDAY"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("SUN"++Rest, Acc) -> tokenise(Rest, Acc);

%% Hmm Excel reports GMT in times so nuke that too
tokenise("GMT"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("UTC"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("DST"++Rest, Acc) -> tokenise(Rest, Acc); % daylight saving time

tokenise([$, | Rest], Acc) -> tokenise(Rest, Acc);
tokenise([32 | Rest], Acc) -> tokenise(Rest, Acc); % Spaces
tokenise("TH"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("ND"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("ST"++Rest, Acc) -> tokenise(Rest, Acc);
tokenise("OF"++Rest, Acc) -> tokenise(Rest, Acc);

tokenise([Else | Rest], Acc) ->
    tokenise(Rest, [{bad_token, Else} | Acc]).

hour(Hour, []) -> Hour;
hour(Hour, [am]) -> Hour;
hour(Hour, [pm]) -> Hour+12.

-spec format(string(),datetime(),list()) -> string().
%% Finished, return
format([], _Date, Acc) ->
    lists:flatten(lists:reverse(Acc));

%% Escape backslashes
format([$\\,H|T], Dt, Acc) ->
    format(T,Dt,[H|Acc]);

%% Year Formats
format([$Y|T], {{Y,_,_},_}=Dt, Acc) ->
    format(T, Dt, [itol(Y)|Acc]);
format([$y|T], {{Y,_,_},_}=Dt, Acc) ->
    [_, _, Y3, Y4] = itol(Y),
    format(T, Dt, [[Y3,Y4]|Acc]);
format([$L|T], {{Y,_,_},_}=Dt, Acc) ->
    format(T, Dt, [itol(is_leap(Y))|Acc]);
format([$o|T], {Date,_}=Dt, Acc) ->
    format(T, Dt, [itol(iso_year(Date))|Acc]);

%% Month Formats
format([$n|T], {{_,M,_},_}=Dt, Acc) ->
    format(T, Dt, [itol(M)|Acc]);
format([$m|T], {{_,M,_},_}=Dt, Acc) ->
    format(T, Dt, [pad2(M)|Acc]);
format([$M|T], {{_,M,_},_}=Dt, Acc) ->
    format(T, Dt, [smonth(M)|Acc]);
format([$F|T], {{_,M,_},_}=Dt, Acc) ->
    format(T, Dt, [month(M)|Acc]);
format([$t|T], {{Y,M,_},_}=Dt, Acc) ->
    format(T, Dt, [itol(calendar:last_day_of_the_month(Y,M))|Acc]);

%% Week Formats
format([$W|T], {Date,_}=Dt, Acc) ->
    format(T, Dt, [pad2(iso_week(Date))|Acc]);

%% Day Formats
format([$j|T], {{_,_,D},_}=Dt, Acc) ->
    format(T, Dt, [itol(D)|Acc]);
format([$S|T], {{_,_,D},_}=Dt, Acc) ->
    format(T, Dt,[suffix(D)| Acc]);
format([$d|T], {{_,_,D},_}=Dt, Acc) ->
    format(T, Dt, [pad2(D)|Acc]);
format([$D|T], {Date,_}=Dt, Acc) ->
    format(T, Dt, [sdayd(Date)|Acc]);
format([$l|T], {Date,_}=Dt, Acc) ->
    format(T, Dt, [day(calendar:day_of_the_week(Date))|Acc]);
format([$N|T], {Date,_}=Dt, Acc) ->
    format(T, Dt, [itol(calendar:day_of_the_week(Date))|Acc]);
format([$w|T], {Date,_}=Dt, Acc) ->
    format(T, Dt, [itol(to_w(calendar:day_of_the_week(Date)))|Acc]);
format([$z|T], {Date,_}=Dt, Acc) ->
    format(T, Dt, [itol(days_in_year(Date))|Acc]);

%% Time Formats
format([$a|T], {_,{H,_,_}}=Dt, Acc) when H > 12 ->
    format(T, Dt, ["pm"|Acc]);
format([$a|T], Dt, Acc) ->
    format(T, Dt, ["am"|Acc]);
format([$A|T], {_,{H,_,_}}=Dt, Acc) when H > 12 ->
    format(T, Dt, ["PM"|Acc]);
format([$A|T], Dt, Acc) ->
    format(T, Dt, ["AM"|Acc]);
format([$g|T], {_,{H,_,_}}=Dt, Acc) when H == 12; H == 0 ->
    format(T, Dt, ["12"|Acc]);
format([$g|T], {_,{H,_,_}}=Dt, Acc) when H > 12 ->
    format(T, Dt, [itol(H-12)|Acc]);
format([$g|T], {_,{H,_,_}}=Dt, Acc) ->
    format(T, Dt, [itol(H)|Acc]);
format([$G|T], {_,{H,_,_}}=Dt, Acc) ->
    format(T, Dt, [itol(H)|Acc]);
format([$h|T], {_,{H,_,_}}=Dt, Acc) when H > 12 ->
    format(T, Dt, [pad2(H-12)|Acc]);
format([$h|T], {_,{H,_,_}}=Dt, Acc) ->
    format(T, Dt, [pad2(H)|Acc]);
format([$H|T], {_,{H,_,_}}=Dt, Acc) ->
    format(T, Dt, [pad2(H)|Acc]);
format([$i|T], {_,{_,M,_}}=Dt, Acc) ->
    format(T, Dt, [pad2(M)|Acc]);
format([$s|T], {_,{_,_,S}}=Dt, Acc) ->
    format(T, Dt, [pad2(S)|Acc]);

%% Whole Dates
format([$c|T], {{Y,M,D},{H,Min,S}}=Dt, Acc) ->
    Format = "~4.10.0B-~2.10.0B-~2.10.0B"
        ++" ~2.10.0B:~2.10.0B:~2.10.0B",
    Date = io_lib:format(Format, [Y, M, D, H, Min, S]),
    format(T, Dt, [Date|Acc]);
format([$r|T], {{Y,M,D},{H,Min,S}}=Dt, Acc) ->
    Format = "~s, ~p ~s ~p ~2.10.0B:~2.10.0B:~2.10.0B",
    Args = [sdayd({Y,M,D}), D, smonth(M), Y, H, Min, S],
    format(T, Dt, [io_lib:format(Format, Args)|Acc]);
format([$U|T], Dt, Acc) ->
    Epoch = {{1970,1,1},{0,0,0}},
    Time = calendar:datetime_to_gregorian_seconds(Dt) -
        calendar:datetime_to_gregorian_seconds(Epoch),
    format(T, Dt, [itol(Time)|Acc]);

%% Unrecognised, print as is
format([H|T], Date, Acc) ->
    format(T, Date, [H|Acc]).


%% @doc days in year
-spec days_in_year(date()) -> integer().
days_in_year({Y,_,_}=Date) ->
    calendar:date_to_gregorian_days(Date) -
        calendar:date_to_gregorian_days({Y,1,1}).

%% @doc is a leap year
-spec is_leap(year()) -> 1|0.
is_leap(Y) ->
    case calendar:is_leap_year(Y) of
        true -> 1;
        false -> 0
    end.

%% @doc Made up numeric day of the week
%% (0 Sunday -> 6 Saturday)
-spec to_w(daynum()) -> integer().
to_w(7) -> 0;
to_w(X) -> X.

-spec suffix(day()) -> string().
%% @doc English ordinal suffix for the day of the
%% month, 2 characters
suffix(1) -> "st";
suffix(2) -> "nd";
suffix(3) -> "rd";
suffix(_) -> "th".

-spec sdayd(date()) -> string().
%% @doc A textual representation of a day, three letters
sdayd({Y,M,D}) ->
    sday(calendar:day_of_the_week({Y,M,D})).

-spec sday(daynum()) -> string().
%% @doc A textual representation of a day, three letters
sday(1) -> "Mon";
sday(2) -> "Tue";
sday(3) -> "Wed";
sday(4) -> "Thu";
sday(5) -> "Fri";
sday(6) -> "Sat";
sday(7) -> "Sun".

-spec day(daynum()) -> string().
%% @doc A full textual representation of a day
day(1) -> "Monday";
day(2) -> "Tuesday";
day(3) -> "Wednesday";
day(4) -> "Thursday";
day(5) -> "Friday";
day(6) -> "Saturday";
day(7) -> "Sunday".

-spec smonth(month()) -> string().
%% @doc A short textual representation of a
%% month, three letters
smonth(1) -> "Jan";
smonth(2) -> "Feb";
smonth(3) -> "Mar";
smonth(4) -> "Apr";
smonth(5) -> "May";
smonth(6) -> "Jun";
smonth(7) -> "Jul";
smonth(8) -> "Aug";
smonth(9) -> "Sep";
smonth(10) -> "Oct";
smonth(11) -> "Nov";
smonth(12) -> "Dec".

-spec month(month()) -> string().
%% @doc A full textual representation of a month
month(1) -> "January";
month(2) -> "February";
month(3) -> "March";
month(4) -> "April";
month(5) -> "May";
month(6) -> "June";
month(7) -> "July";
month(8) -> "August";
month(9) -> "September";
month(10) -> "October";
month(11) -> "November";
month(12) -> "December".

-spec iso_week(date()) -> integer().
%% @doc The week of the years as defined in ISO 8601
%% http://en.wikipedia.org/wiki/ISO_week_date
iso_week(Date) ->
    Week = iso_week_one(iso_year(Date)),
    Days = calendar:date_to_gregorian_days(Date) -
        calendar:date_to_gregorian_days(Week),
    trunc((Days / 7) + 1).

-spec iso_year(date()) -> integer().
%% @doc The year number as defined in ISO 8601
%% http://en.wikipedia.org/wiki/ISO_week_date
iso_year({Y, _M, _D}=Dt) ->
    case Dt >= {Y, 12, 29} of
        true ->
            case Dt < iso_week_one(Y+1) of
                true -> Y;
                false -> Y+1
            end;
        false ->
            case Dt < iso_week_one(Y) of
                true -> Y-1;
                false -> Y
            end
    end.

-spec iso_week_one(year()) -> date().
%% @doc The date of the the first day of the first week
%% in the ISO calendar
iso_week_one(Y) ->
    Day1 = calendar:day_of_the_week({Y,1,4}),
    Days = calendar:date_to_gregorian_days({Y,1,4}) + (1-Day1),
    calendar:gregorian_days_to_date(Days).

-spec itol(integer()) -> list().
%% @doc short hand
itol(X) ->
    integer_to_list(X).

-spec pad2(integer()) -> list().
%% @doc int padded with 0 to make sure its 2 chars
pad2(X) when is_integer(X) ->
    io_lib:format("~2.10.0B",[X]);
pad2(X) when is_float(X) ->
    io_lib:format("~2.10.0B",[trunc(X)]).

ltoi(X) ->
    list_to_integer(X).

%%
%% TEST FUNCTIONS
%%
%% c(dh_date,[{d,'TEST'}]).
%-define(NOTEST, 1).

-include_lib("eunit/include/eunit.hrl").

-define(DATE, {{2001,3,10},{17,16,17}}).
-define(ISO, "o \\WW").

basic_format_test_() ->
    [
     ?_assertEqual(format("F j, Y, g:i a",?DATE), "March 10, 2001, 5:16 pm"),
     ?_assertEqual(format("m.d.y",?DATE), "03.10.01"),
     ?_assertEqual(format("j, n, Y",?DATE), "10, 3, 2001"),
     ?_assertEqual(format("Ymd",?DATE), "20010310"),
     ?_assertEqual(format("H:i:s",?DATE), "17:16:17"),
     ?_assertEqual(format("z",?DATE), "68"),
     ?_assertEqual(format("D M j G:i:s Y",?DATE), "Sat Mar 10 17:16:17 2001"),

     ?_assertEqual(format("h-i-s, j-m-y, it is w Day",?DATE),
                   "05-16-17, 10-03-01, 1631 1617 6 Satpm01"),
     ?_assertEqual(format("\\i\\t \\i\\s \\t\\h\\e\\ jS \\d\\a\\y.",?DATE),
                   "it is the 10th day."),
     ?_assertEqual(format("H:m:s \\m \\i\\s \\m\\o\\n\\t\\h",?DATE),
                   "17:03:17 m is month")
    ].

basic_parse_test_() ->
    [
     ?_assertEqual({{2008,8,22}, {17,16,17}},
                   parse("22nd of August 2008", ?DATE)),
     ?_assertEqual({{2008,8,22}, {6,35,0}},
                   parse("22-Aug-2008 6:35 AM", ?DATE)),
     ?_assertEqual({{2008,8,22}, {6,35,12}},
                   parse("22-Aug-2008 6:35:12 AM", ?DATE)),
     ?_assertEqual({{2008,8,22}, {6,35,0}},
                   parse("August/22/2008 6:35 AM", ?DATE)),
     ?_assertEqual({{2008,8,22}, {6,35,0}},
                   parse("22 August 2008 6:35 AM", ?DATE)),
     ?_assertEqual({{2008,8,22}, {6,35,0}},
                   parse("22 Aug 2008 6:35AM", ?DATE)),
     ?_assertEqual({{2008,8,22}, {6,35,0}},
                   parse("22 Aug 2008 6:35 AM", ?DATE)),
     ?_assertEqual({{2008,8,22}, {6,35,0}},
                   parse("22 Aug 2008 6:35", ?DATE)),
     ?_assertEqual({{2008,8,22}, {18,35,0}},
                   parse("22 Aug 2008 6:35 PM", ?DATE)),
     ?_assertEqual({{2001,3,10}, {11,15,0}},
                   parse("11:15", ?DATE)),
     ?_assertEqual({{2001,3,10}, {1,15,0}},
                   parse("1:15", ?DATE)),
     ?_assertEqual({{2001,3,10}, {1,15,0}},
                   parse("1:15 am", ?DATE)),
     ?_assertEqual({{2001,3,10}, {3,45,39}},
                   parse("3:45:39", ?DATE)),
     ?_assertEqual({{1963,4,23}, {17,16,17}},
                   parse("23-4-1963", ?DATE)),
     ?_assertEqual({{1963,4,23}, {17,16,17}},
                   parse("23-april-1963", ?DATE)),
     ?_assertEqual({{1963,4,23}, {17,16,17}},
                   parse("23-apr-1963", ?DATE)),
     ?_assertEqual({{1963,4,23}, {17,16,17}},
                   parse("4/23/1963", ?DATE)),
     ?_assertEqual({{1963,4,23}, {17,16,17}},
                   parse("april/23/1963", ?DATE)),
     ?_assertEqual({{1963,4,23}, {17,16,17}},
                   parse("apr/23/1963", ?DATE)),
     ?_assertEqual({{1963,4,23}, {17,16,17}},
                   parse("1963/4/23", ?DATE)),
     ?_assertEqual({{1963,4,23}, {17,16,17}},
                   parse("1963/april/23", ?DATE)),
     ?_assertEqual({{1963,4,23}, {17,16,17}},
                   parse("1963/apr/23", ?DATE)),
     ?_assertEqual({{1963,4,23}, {17,16,17}},
                   parse("1963-4-23", ?DATE)),
     ?_assertEqual({{1963,4,23}, {17,16,17}},
                   parse("1963-4-23", ?DATE)),
     ?_assertEqual({{1963,4,23}, {17,16,17}},
                   parse("1963-apr-23", ?DATE)),
     ?_assertThrow({?MODULE, {bad_date, "23/ap/195"}},
                   parse("23/ap/195", ?DATE)),
     ?_assertEqual({{2001,3,10}, {6,45,0}},
                   parse("6:45 am", ?DATE)),
     ?_assertEqual({{2001,3,10}, {18,45,0}},
                   parse("6:45 PM", ?DATE)),
     ?_assertEqual({{2001,3,10}, {18,45,0}},
                   parse("6:45 PM ", ?DATE))
    ].

parse_with_days_test_() ->
    [
     ?_assertEqual({{2008,8,22}, {17,16,17}},
                   parse("Sat 22nd of August 2008", ?DATE)),
     ?_assertEqual({{2008,8,22}, {6,35,0}},
                   parse("Sat, 22-Aug-2008 6:35 AM", ?DATE)),
     ?_assertEqual({{2008,8,22}, {6,35,12}},
                   parse("Sunday 22-Aug-2008 6:35:12 AM", ?DATE)),
     ?_assertEqual({{2008,8,22}, {6,35,0}},
                   parse("Sun 22-Aug-2008 6:35 AM", ?DATE)),
     ?_assertEqual({{2008,8,22}, {6,35,0}},
                   parse("THURSDAY, 22-August-2008 6:35 AM", ?DATE)),
     ?_assertEqual({{2008,8,22}, {6,35,0}},
                   parse("THU 22 August 2008 6:35 AM", ?DATE)),
     ?_assertEqual({{2008,8,22}, {6,35,0}},
                   parse("FRi 22 Aug 2008 6:35AM", ?DATE)),
     ?_assertEqual({{2008,8,22}, {6,35,0}},
                   parse("Wednesday 22 Aug 2008 6:35 AM", ?DATE)),
     ?_assertEqual({{2008,8,22}, {6,35,0}},
                   parse("Monday 22 Aug 2008 6:35", ?DATE)),
     ?_assertEqual({{2008,8,22}, {18,35,0}},
                   parse("Mon, 22 Aug 2008 6:35 PM", ?DATE))
    ].

parse_with_TZ_test_() ->
    [
     ?_assertEqual({{2008,8,22}, {17,16,17}},
                   parse("Sat 22nd of August 2008 GMT", ?DATE)),
     ?_assertEqual({{2008,8,22}, {17,16,17}},
                   parse("Sat 22nd of August 2008 UTC", ?DATE)),
     ?_assertEqual({{2008,8,22}, {17,16,17}},
                   parse("Sat 22nd of August 2008 DST", ?DATE))
    ].

iso_test_() ->
    [
     ?_assertEqual("2004 W53",format(?ISO,{{2005,1,1}, {1,1,1}})),
     ?_assertEqual("2004 W53",format(?ISO,{{2005,1,2}, {1,1,1}})),
     ?_assertEqual("2005 W52",format(?ISO,{{2005,12,31},{1,1,1}})),
     ?_assertEqual("2007 W01",format(?ISO,{{2007,1,1}, {1,1,1}})),
     ?_assertEqual("2007 W52",format(?ISO,{{2007,12,30},{1,1,1}})),
     ?_assertEqual("2008 W01",format(?ISO,{{2007,12,31},{1,1,1}})),
     ?_assertEqual("2008 W01",format(?ISO,{{2008,1,1}, {1,1,1}})),
     ?_assertEqual("2009 W01",format(?ISO,{{2008,12,29},{1,1,1}})),
     ?_assertEqual("2009 W01",format(?ISO,{{2008,12,31},{1,1,1}})),
     ?_assertEqual("2009 W01",format(?ISO,{{2009,1,1}, {1,1,1}})),
     ?_assertEqual("2009 W53",format(?ISO,{{2009,12,31},{1,1,1}})),
     ?_assertEqual("2009 W53",format(?ISO,{{2010,1,3}, {1,1,1}}))
    ].