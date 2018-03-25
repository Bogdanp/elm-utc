module Time.DateTime
    exposing
        ( DateTime
        , DateTimeDelta
        , addDays
        , addHours
        , addMilliseconds
        , addMinutes
        , addMonths
        , addSeconds
        , addYears
        , compare
        , date
        , dateTime
        , day
        , delta
        , epoch
        , fromISO8601
        , fromTimestamp
        , fromTuple
        , hour
        , isValidTime
        , millisecond
        , minute
        , month
        , second
        , setDate
        , setDay
        , setHour
        , setMillisecond
        , setMinute
        , setMonth
        , setSecond
        , setYear
        , toISO8601
        , toTimestamp
        , toTuple
        , weekday
        , year
        , zero
        )

{-| This module defines a time representation based on a Date and the
time of day.


# DateTimes

@docs DateTime, zero, epoch, dateTime, date, year, month, day, weekday, hour, minute, second, millisecond


# Manipulating DateTimes

@docs setDate, setYear, setMonth, setDay, setHour, setMinute, setSecond, setMillisecond, addYears, addMonths, addDays, addHours, addMinutes, addSeconds, addMilliseconds


# Comparing DateTimes

@docs compare


# Subtracting DateTimes

@docs DateTimeDelta, delta


# Helper functions

@docs isValidTime, toTimestamp, fromTimestamp, toTuple, fromTuple, toISO8601, fromISO8601

-}

--import Combine exposing (..)
--import Combine.Num

import Char
import Parser
    exposing
        ( (|.)
        , (|=)
        , Count(..)
        , Parser
        , andThen
        , delayedCommit
        , end
        , fail
        , ignore
        , inContext
        , keep
        , oneOf
        , oneOrMore
        , run
        , source
        , succeed
        , symbol
        , zeroOrMore
        )
import String exposing (cons, slice, toInt, uncons)
import Time exposing (Time)
import Time.Date exposing (Date, Weekday, isValidDate, parseDate)
import Time.Internal exposing (..)


{-| DateTime is the opaque type for all DateTime values. Values of this
type represent a valid Date and a time offset from midnight.
-}
type DateTime
    = DateTime
        { date : Date
        , offset : Int
        }


{-| DateTimeDelta represents the relative difference between two
DateTime values.
-}
type alias DateTimeDelta =
    { years : Int
    , months : Int
    , days : Int
    , hours : Int
    , minutes : Int
    , seconds : Int
    , milliseconds : Int
    }


{-| Offset is expressed in +/- milliseconds
-}
type alias Milliseconds =
    Int


{-| zero represents the first millisecond of the first day of the
current era. Use it to construct `DateTime` values:

    -- 0-01-01T00:00:00Z
    dateTime zero

    -- 2016-01-01T00:00:00Z
    dateTime { zero | year = 2016 }

    -- 2016-05-29T13:00:00Z
    dateTime { zero | year = 2016, month = 5, day = 29, hour = 13 }

-}
zero : DateTimeData
zero =
    Time.Internal.zero


{-| epoch is the instant in time that represents the first millisecond
of the UNIX Epoch.
-}
epoch : DateTime
epoch =
    dateTime { zero | year = 1970 }


{-| dateTime constructs a DateTime value given a date and a time.
Invalid values are clamped to the nearest valid date and time.
-}
dateTime : DateTimeData -> DateTime
dateTime ({ year, month, day } as data) =
    DateTime
        { date = Time.Date.date year month day
        , offset = offsetFromTimeData data
        }


mkDateTime : Date -> TimeData d -> DateTime
mkDateTime date time =
    DateTime { date = date, offset = offsetFromTimeData time }


{-| date returns a DateTime's Date.
-}
date : DateTime -> Date
date (DateTime { date }) =
    date


{-| year returns a DateTime's year.
-}
year : DateTime -> Int
year (DateTime { date }) =
    Time.Date.year date


{-| month returns a DateTime's month.
-}
month : DateTime -> Int
month (DateTime { date }) =
    Time.Date.month date


{-| day returns a DateTime's day.
-}
day : DateTime -> Int
day (DateTime { date }) =
    Time.Date.day date


{-| weekday returns a DateTime's day of the week.
-}
weekday : DateTime -> Weekday
weekday (DateTime { date }) =
    Time.Date.weekday date


{-| hour returns a DateTime's hour.
-}
hour : DateTime -> Int
hour (DateTime { offset }) =
    offset // hourMs


{-| minute returns a DateTime's minute.
-}
minute : DateTime -> Int
minute (DateTime { offset }) =
    (offset % hourMs) // minuteMs


{-| second returns a DateTime's second.
-}
second : DateTime -> Int
second (DateTime { offset }) =
    (offset % hourMs % minuteMs) // secondMs


{-| millisecond returns a DateTime's millisecond.
-}
millisecond : DateTime -> Int
millisecond (DateTime { offset }) =
    offset % hourMs % minuteMs % secondMs


{-| setDate sets a DateTime's Date.
-}
setDate : Date -> DateTime -> DateTime
setDate date (DateTime { offset }) =
    DateTime
        { date = date
        , offset = offset
        }


{-| setYear sets a DateTime's year.

See also `Time.Date.setYear`.

-}
setYear : Int -> DateTime -> DateTime
setYear year (DateTime { date, offset }) =
    DateTime
        { date = Time.Date.setYear year date
        , offset = offset
        }


{-| setMonth sets a DateTime's month.

See also `Time.Date.setMonth`.

-}
setMonth : Int -> DateTime -> DateTime
setMonth month (DateTime { date, offset }) =
    DateTime
        { date = Time.Date.setMonth month date
        , offset = offset
        }


{-| setDay sets a DateTime's day.

See also `Time.Date.setDay`.

-}
setDay : Int -> DateTime -> DateTime
setDay day (DateTime { date, offset }) =
    DateTime
        { date = Time.Date.setDay day date
        , offset = offset
        }


{-| setHour sets a DateTime's hour.
-}
setHour : Int -> DateTime -> DateTime
setHour hour ((DateTime { date }) as t) =
    mkDateTime date
        { hour = hour
        , minute = minute t
        , second = second t
        , millisecond = millisecond t
        }


{-| setMinute sets a DateTime's minute, returning Nothing if the
updated time is invalid or Just the new DateTime.
-}
setMinute : Int -> DateTime -> DateTime
setMinute minute ((DateTime { date }) as t) =
    mkDateTime date
        { hour = hour t
        , minute = minute
        , second = second t
        , millisecond = millisecond t
        }


{-| setSecond sets a DateTime's second, returning Nothing if the
updated time is invalid or Just the new DateTime.
-}
setSecond : Int -> DateTime -> DateTime
setSecond second ((DateTime { date }) as t) =
    mkDateTime date
        { hour = hour t
        , minute = minute t
        , second = second
        , millisecond = millisecond t
        }


{-| setMillisecond sets a DateTime's millisecond, returning Nothing if
the updated time is invalid or Just the new DateTime.
-}
setMillisecond : Int -> DateTime -> DateTime
setMillisecond millisecond ((DateTime { date }) as t) =
    mkDateTime date
        { hour = hour t
        , minute = minute t
        , second = second t
        , millisecond = millisecond
        }


{-| addYears adds a relative number of years to a DateTime value.

See also `Time.Date.addYears`.

-}
addYears : Int -> DateTime -> DateTime
addYears years (DateTime { date, offset }) =
    DateTime
        { date = Time.Date.addYears years date
        , offset = offset
        }


{-| addMonths adds a relative number of months to a DateTime value.

See also `Time.Date.addMonths`.

-}
addMonths : Int -> DateTime -> DateTime
addMonths months (DateTime { date, offset }) =
    DateTime
        { date = Time.Date.addMonths months date
        , offset = offset
        }


{-| addDays adds an absolute number of days to a DateTime value.

See also `Time.Date.addDays`.

-}
addDays : Int -> DateTime -> DateTime
addDays days (DateTime { date, offset }) =
    DateTime
        { date = Time.Date.addDays days date
        , offset = offset
        }


{-| addHours adds a relative number of hours to a DateTime value.
-}
addHours : Int -> DateTime -> DateTime
addHours hours time =
    addMilliseconds (hours * hourMs) time


{-| addMinutes adds a relative number of minutes to a DateTime value.
-}
addMinutes : Int -> DateTime -> DateTime
addMinutes minutes time =
    addMilliseconds (minutes * minuteMs) time


{-| addSeconds adds a relative number of seconds to a DateTime value.
-}
addSeconds : Int -> DateTime -> DateTime
addSeconds seconds time =
    addMilliseconds (seconds * secondMs) time


{-| addMilliseconds adds an absolute number of milliseconds to a
DateTime value.
-}
addMilliseconds : Int -> DateTime -> DateTime
addMilliseconds ms (DateTime { date, offset }) =
    let
        total =
            ms + offset

        ( days, newOffset ) =
            if total < 0 then
                let
                    days =
                        -(abs total // dayMs + 1)

                    offset =
                        rem total dayMs
                in
                if offset == 0 then
                    ( days + 1, 0 )
                else
                    ( days, dayMs + rem offset dayMs )
            else
                ( total // dayMs, rem total dayMs )
    in
    DateTime
        { date = Time.Date.addDays days date
        , offset = newOffset
        }


{-| compare two DateTimes.
-}
compare : DateTime -> DateTime -> Order
compare dt1 dt2 =
    -- comparison of 7-tuples is not supported so we use toISO8601 instead
    Basics.compare (toISO8601 dt1) (toISO8601 dt2)


{-| delta computes the relative difference between two DateTime values.
-}
delta : DateTime -> DateTime -> DateTimeDelta
delta (DateTime t1) (DateTime t2) =
    let
        { years, months, days } =
            Time.Date.delta t1.date t2.date

        milliseconds =
            days * dayMs + (t1.offset - t2.offset)

        hours =
            milliseconds // hourMs

        minutes =
            milliseconds // minuteMs

        seconds =
            milliseconds // secondMs
    in
    { years = years
    , months = months
    , days = days
    , hours = hours
    , minutes = minutes
    , seconds = seconds
    , milliseconds = milliseconds
    }


{-| isValidTime returns True if the given hour, minute, second and
millisecond represent a valid time of day.
-}
isValidTime : Int -> Int -> Int -> Int -> Bool
isValidTime hour minute second millisecond =
    hour >= 0 && hour < 24 && minute >= 0 && minute < 60 && second >= 0 && second < 60 && millisecond >= 0 && millisecond < 1000


{-| toTimestamp converts a DateTime value to its UNIX timestamp
representation as milliseconds.
-}
toTimestamp : DateTime -> Time
toTimestamp time =
    delta time epoch
        |> .milliseconds
        |> toFloat


{-| fromTimestamp converts the millisecond representation of a
UNIX timestamp into a DateTime value.
-}
fromTimestamp : Time -> DateTime
fromTimestamp timestamp =
    addMilliseconds (round timestamp) epoch


{-| toTuple converts a DateTime into a (year, month, day, hour, miunte,
second, millisecond) tuple.
-}
toTuple : DateTime -> ( Int, Int, Int, Int, Int, Int, Int )
toTuple ((DateTime { date }) as t) =
    let
        ( year, month, day ) =
            Time.Date.toTuple date
    in
    ( year, month, day, hour t, minute t, second t, millisecond t )


{-| fromTuple converts a (year, month, day, hour, minute, second,
millisecond) tuple into a DateTime.
-}
fromTuple : ( Int, Int, Int, Int, Int, Int, Int ) -> DateTime
fromTuple ( year, month, day, hour, minute, second, millisecond ) =
    dateTime
        { year = year
        , month = month
        , day = day
        , hour = hour
        , minute = minute
        , second = second
        , millisecond = millisecond
        }


{-| toISO8601 renders a DateTime in ISO8601 format.
-}
toISO8601 : DateTime -> String
toISO8601 time =
    toString (year time)
        ++ "-"
        ++ padded (month time)
        ++ "-"
        ++ padded (day time)
        ++ "T"
        ++ padded (hour time)
        ++ ":"
        ++ padded (minute time)
        ++ ":"
        ++ padded (second time)
        ++ "."
        ++ padded3 (millisecond time)
        ++ "Z"


{-| fromISO8601 parses an ISO8601-formatted date time string into a
DateTime object, adjusting for its timezone offset.
-}
fromISO8601 : String -> Result Parser.Error DateTime
fromISO8601 input =
    run parseDateTime input


parseDateTime : Parser DateTime
parseDateTime =
    (succeed (,,)
        |= parseDate
        |. optional 'T'
        |= parseOffset
        |= tZOffset
    )
        |> andThen convertDateTime


parseOffset : Parser Milliseconds
parseOffset =
    (succeed (,,,)
        |= digitsInRange "hours" 2 0 23
        |. optional ':'
        |= digitsInRange "minutes" 2 0 59
        |. optional ':'
        |= digitsInRange "seconds" 2 0 59
        |= fraction
    )
        |> andThen convertTime


convertDateTime : ( Date, Milliseconds, Milliseconds ) -> Parser DateTime
convertDateTime ( date, offset, tZOffset ) =
    succeed
        (DateTime { date = date, offset = offset }
            |> addMilliseconds tZOffset
        )


convertTime : ( Int, Int, Int, Int ) -> Parser Milliseconds
convertTime ( hours, minutes, seconds, milliseconds ) =
    succeed
        (offsetFromTimeData
            { hour = hours
            , minute = minutes
            , second = seconds
            , millisecond = milliseconds
            }
        )


fraction : Parser Milliseconds
fraction =
    oneOf
        [ optionalFraction
        , succeed 0
        ]


optionalFraction : Parser Milliseconds
optionalFraction =
    inContext "fraction" <|
        ((succeed identity
            |. keep (Exactly 1) ((==) '.')
            |= keep oneOrMore Char.isDigit
         )
            |> andThen (fromResult << getFraction)
        )


getFraction : String -> Result String Milliseconds
getFraction fractionString =
    let
        numerator =
            Result.withDefault 0 (String.toInt fractionString)

        denominator =
            10 ^ String.length fractionString
    in
    Ok (round (Time.Internal.secondMs * toFloat numerator / toFloat denominator))


tZOffset : Parser Milliseconds
tZOffset =
    oneOf
        [ utc
        , optionalTZOffset
        , succeed 0
        ]


utc : Parser Milliseconds
utc =
    (succeed identity
        |. keep (Exactly 1) ((==) 'Z')
    )
        |> andThen (fromResult << (\_ -> Ok 0))


optionalTZOffset : Parser Milliseconds
optionalTZOffset =
    inContext "offset" <|
        ((succeed (,,)
            |= polarity
            |= digitsInRange "timezone hours" 2 0 23
            |. optional ':'
            |= digitsInRange "timezone minutes" 2 0 59
         )
            |> andThen (fromResult << getTZOffset)
        )


polarity : Parser Int
polarity =
    inContext "timezone polarity" <|
        (keep (Exactly 1)
            (\c ->
                c
                    == '+'
                    || c
                    == '-'
                    || c
                    == '−'
             --U+2212
            )
            |> andThen
                (fromResult
                    << -- Code has to do opposite of sign char
                       (\sign ->
                            if sign == "+" then
                                Ok -1
                            else
                                Ok 1
                       )
                )
        )


getTZOffset : ( Int, Int, Int ) -> Result String Milliseconds
getTZOffset ( polarity, hrs, min ) =
    Ok
        (polarity
            * hrs
            * hourMs
            + polarity
            * min
            * minuteMs
        )
