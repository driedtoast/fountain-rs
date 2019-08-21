port module Main exposing (Model, Msg(..), ensureTrailingNewline, init, main, update, view)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Html.Parser
import Html.Parser.Util exposing (toVirtualDom)
import Http exposing (Error(..))
import Json.Decode as Decode
import Json.Encode as Enc
import Parser exposing (deadEndsToString)
import String exposing (endsWith)



-- ---------------------------
-- MODEL
-- ---------------------------


{-| The entire app's state. Similar to the Store in React/Redux.
-}
type alias Model =
    { plaintextScreenplay : String -- Plain text the user types in, encoded in Fountain markup
    , renderedScreenplay : String -- The styled text, generated from the plaintext
    , serverMessage : String -- Error messages if the user's markup was invalid
    , fullscreen : Bool
    }


{-| What should the Model be when the user starts the app?
-}
init : String -> ( Model, Cmd Msg )
init flags =
    ( { plaintextScreenplay = flags
      , serverMessage = ""
      , renderedScreenplay = exampleHTML
      , fullscreen = False
      }
    , Cmd.none
    )



-- ---------------------------
-- UPDATE
-- ---------------------------


{-| Union/enum/ADT of every event that could happen in the app.
-}
type Msg
    = ChangeScreenplay String -- User edited their plaintext screenplay
    | RenderBtnPress -- User pressed the Render button
    | PrintViewPress -- User pressed the Print View button
    | RenderResponse (Result Http.Error String) -- The backend returned with rendered screenplay


{-| Given some Msg, and the current Model, output the new model and a side-effect to execute.
-}
update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        ChangeScreenplay s ->
            ( { model | plaintextScreenplay = s }, Cmd.none )

        RenderBtnPress ->
            ( model, postScreenplay model.plaintextScreenplay )

        PrintViewPress ->
            ( { model | fullscreen = not model.fullscreen }, Cmd.none )

        RenderResponse res ->
            case res of
                Ok r ->
                    ( { model | renderedScreenplay = r }, Cmd.none )

                Err err ->
                    ( { model | serverMessage = "Error: " ++ httpErrorToString err }, Cmd.none )


httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        BadUrl _ ->
            "BadUrl"

        Timeout ->
            "Timeout"

        NetworkError ->
            "NetworkError"

        BadStatus _ ->
            "BadStatus"

        BadBody s ->
            "BadBody: " ++ s



-- ---------------------------
-- HTTP
-- ---------------------------


{-| Send HTTP request to the Fountain backend. Request contains the plaintext screenplay,
response will contain the rendered screenplay.
-}
postScreenplay : String -> Cmd Msg
postScreenplay s =
    Http.post
        { url = "https://screenplay.page/renderfountain"
        , body =
            Http.jsonBody <|
                Enc.object
                    [ ( "screenplay", Enc.string <| ensureTrailingNewline s )
                    ]
        , expect = Http.expectString RenderResponse
        }


ensureTrailingNewline s =
    if endsWith "\n" s then
        s

    else
        s ++ "\n"



-- ---------------------------
-- VIEW
-- ---------------------------


view : Model -> Html Msg
view model =
    if model.fullscreen then
        viewOnePane model

    else
        viewTwoPane model


viewOnePane : Model -> Html Msg
viewOnePane model =
    div [ class "container-one-pane" ]
        [ pageHeader
        , div [ class "editor editor-out editor-out-full" ] (outputPane model)
        ]


viewTwoPane : Model -> Html Msg
viewTwoPane model =
    div [ class "container-two-pane" ]
        [ pageHeader
        , div [ class "editor editor-in" ]
            [ userTextInput model
            , br [] []
            ]
        , div [ class "editor editor-out" ]
            (outputPane model)
        , footerDiv
        ]


pageHeader =
    header []
        [ h1 [] [ text "Write Your Screenplay" ]
        , div []
            [ printViewBtn
            , renderBtn
            ]
        ]


footerDiv =
    footer []
        [ p []
            [ text "Made by "
            , link "https://twitter.com/adam_chal" "@adam_chal"
            , text ". Parsing done in Rust via my "
            , link "https://crates.io/crates/fountain" "Fountain"
            , text " crate, which is compiled into WebAssembly and run in the browser via "
            , link "https://blog.cloudflare.com/introducing-wrangler-cli/" "Cloudflare Workers"
            , text ". Frontend written in Elm. Functionality also available via "
            , link "https://github.com/adamchalmers/fountain-rs" "CLI"
            ]
        ]


{-| Convenience function for simpler <a> links
-}
link to txt =
    a [ href to, target "_blank" ] [ text txt ]


{-| When users click this button, the backend will style their screenplay
-}
renderBtn =
    button
        [ class "pure-button pure-button-primary", onClick RenderBtnPress ]
        [ text "Render screenplay" ]


{-| When users click this button, the backend will style their screenplay
-}
printViewBtn =
    button
        [ class "pure-button", onClick PrintViewPress ]
        [ text "Toggle print view" ]


{-| This is where users type their plaintext screenplays
-}
userTextInput model =
    textarea
        [ onInput ChangeScreenplay
        , rows 20
        , cols 40
        ]
        [ text model.plaintextScreenplay ]


{-| This is where users see their rendered screenplay
-}
outputPane model =
    if model.serverMessage == "" then
        case Html.Parser.run model.renderedScreenplay of
            Ok html ->
                toVirtualDom html

            Err errs ->
                [ text <| deadEndsToString errs ]

    else
        [ text <| model.serverMessage ]



-- ---------------------------
-- MAIN
-- ---------------------------


{-| Wire all the various components together
-}
main : Program String Model Msg
main =
    Browser.document
        { init = init
        , update = update
        , view =
            \m ->
                { title = "Write a screenplay in Elm"
                , body = [ view m ]
                }
        , subscriptions = \_ -> Sub.none
        }


exampleHTML =
    """<h1 class='titlepage'>Alien</h1>
<h3 class='titlepage'>By Dan O'Bannon</h3>

<p class='page-break'></p>

<p class='scene'>INT. MESS</p>
<p class='action'>The entire crew is seated. Hungrily swallowing huge portions of artificial food. The cat eats from a dish on the table.</p>
<p class='speaker'>KANE</p>
<p class='dialogue'>First thing I'm going to do when we get back is eat some decent food.</p>
<div class='dual-dialogue'>
<p class='speaker'>RIPLEY</p>
<p class='dialogue'>Yeah, right</p>
<p class='speaker'>ASH ^</p>
<p class='dialogue'>Yeah, right</p>
</div> <!-- end dual dialogue -->
<p class='speaker'>KANE</p>
<p class='dialogue'>Wow, sure hope I don't fall pregnant here.</p>
"""
