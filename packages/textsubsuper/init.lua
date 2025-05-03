--
-- Text superscript and subscript package for SILE, using OpenType features when available and enabled.
--
-- License: GPL-3.0-or-later
--
-- Copyright (C) 2021-2025 Didier Willis
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.
--
local base = require("packages.base")

local package = pl.class(base)
package._name = "textsubsuper"

local textFeatCache = {}

local function _key (options, text)
  -- We don't use the size in the cache key, as we don't expect it to
  -- change whether features are supported or not...
  return table.concat({
      text,
      options.family,
      ("%d"):format(options.weight or 0),
      options.style,
      options.variant,
      options.features,
      options.filename,
    }, ";")
end

--- Cache the result of the font features check.
-- @tparam table   options  The font options used to check the features.
-- @tparam string  text     The text content used to check the features.
-- @tparam boolean status   The result of the check.
-- @treturn boolean  The result of the check (cached).
local function textFeatCaching (options, text, status)
  local key = _key(options, text)
  if textFeatCache[key] == nil then
    textFeatCache[key] = status
  end
  return status
end

--- Check if the font features are supported by the font.
-- It shapes a string of text with the given font options and compares
-- the result with the same string of text shaped with the default font
-- options. If the results are different, it should mean that the font features
-- are supported (i.e. they had an effect).
-- @tparam string  features  The font features to check.
-- @tparam AST     content   The text content node to check.
-- @treturn boolean  true if the features are supported, false otherwise.
local function checkFontFeatures (features, content)
  local text = SU.ast.contentToString(content)
  if tonumber(text) ~= nil then
    -- Avoid caching any sequence of digits.
    -- Plus, we want consistency here.
    text="0123456789"
  end
  local fontOptions = SILE.font.loadDefaults({ features = features })
  local supported = textFeatCache[_key(fontOptions, text)]
  if supported ~= nil then
    return supported
  end

  local items1 = SILE.shaper:shapeToken(text, fontOptions)
  local items2 = SILE.shaper:shapeToken(text, SILE.font.loadDefaults({}))

  -- Don't mix up characters supporting the features with those
  -- not supporting them, as it would be ugly in most cases.
  if #items1 ~= #items2 then
    return textFeatCaching(fontOptions, text, false)
  end
  for i = 1, #items1 do
    if items1[i].width == items2[i].width and items1[i].height == items2[i].height then
      return textFeatCaching(fontOptions, text, false)
    end
  end
  return textFeatCaching(fontOptions, text, true)
end

--- Get the italic angle of the current font,
-- so we can take into account an italic correction for raised or lowered
-- superscripts or subscripts.
-- @treturn number  The italic angle of the current font.
local function getItalicAngle ()
  local ot = require("core.opentype-parser")
  local fontoptions = SILE.font.loadDefaults({})
  local face = SILE.font.cache(fontoptions, SILE.shaper.getFace)
  local font = ot.parseFont(face)
  return font.post.italicAngle
end

--- Rescale text nodes to be used as a superscript or subscript.
-- This is a handler of the "inputfilter" package.
-- @tparam AST    node     The node to be rescaled.
-- @tparam AST    content  The original content.
-- @tparam table  args     The arguments for the rescaling (xScale, yScaleNumber, yScaleOther).
-- @treturn AST  The rescaled elements (as a series of AST nodes with rescaling commands).
local function rescaleFilter (node, content, args)
  if type(node) == "table" then return node end
  local result = {}
  local chars = SU.splitUtf8(node)
  for _, char in ipairs(chars) do
    if not tonumber(char) then
      result[#result+1] = SU.ast.createCommand("scalebox", {
        xratio = args.xScale,
        yratio = args.yScaleOther
      }, { char }, {
        lno = content.lno,
        col = content.col,
        pos = content.pos
      })
    else
      result[#result+1] = SU.ast.createCommand("scalebox", {
        xratio = args.xScale,
        yratio = args.yScaleNumber
      }, { char }, {
        lno = content.lno,
        col = content.col,
        pos = content.pos
      })
    end
  end
  return result
end

--- Get the weight class of the current font.
-- This is used to determine the weight adjustment for the superscript or subscript.
-- @treturn number  The weight class of the current font.
local function getWeightClass ()
  -- Provided we return it in the font parser, maybe we could
  -- rather do:
  -- local ot = require("core.opentype-parser")
  -- local fontoptions = SILE.font.loadDefaults({})
  -- local face = SILE.font.cache(fontoptions, SILE.shaper.getFace)
  -- local font = ot.parseFont(face)
  -- return font.os2.usWeightClass
  return SILE.settings:get("font.weight")
end

function package:_init ()
  base._init(self)
  self:loadPackage("inputfilter")
  self:loadPackage("raiselower")
  self:loadPackage("scalebox")
end

function package.declareSettings (_)
  SILE.settings:declare({
    parameter = "textsubsuper.fake",
    type = "boolean",
    default = false,
    help = "If true, fake superscripts or subscripts are used by default"
  })

  SILE.settings:declare({
    parameter = "textsubsuper.scale",
    type = "number",
    default = 0.66,
    help = "Size scaling ratio of a fake superscript or subscript"
  })

  SILE.settings:declare({
    parameter = "textsubsuper.bolder",
    type = "integer",
    default = 200,
    help = "Weight increase of a fake superscript or subscript (e.g. 200 for normal to semibold)"
  })

  SILE.settings:declare({
    parameter = "textsubsuper.vscale.number",
    type = "number",
    default = 0.90,
    help = "Vertical ratio applied to numbers in fake superscript or subscript"
  })

  SILE.settings:declare({
    parameter = "textsubsuper.vscale.other",
    type = "number",
    default = 0.95,
    help = "Vertical ratio applied to numbers in fake superscript or subscript"
  })

  SILE.settings:declare({
    parameter = "textsubsuper.offset.superscript",
    type = "measurement",
    default = SILE.types.measurement("0.70ex"),
    help = "Offset of a fake superscript above the baseline (logically in a font-relative unit such as ex)"
  })

  SILE.settings:declare({
    parameter = "textsubsuper.offset.subscript",
    type = "measurement",
    default = SILE.types.measurement("0.25ex"),
    help = "Offset of a fake subscript below the baseline (logically in a font-relative unit such as ex)"
  })

  -- The features we want to use for numbers in superscripts and subscripts:
  -- Some font have +onum enabled by default.
  -- Some don't even have it (e.g. Brill), but support +lnum for enforcing lining figures.
  -- We try to ensure we are not using oldstyle numbers, nor tabular numbers (fixed-width),
  -- but rather lining numbers (uniform-height and baseline-aligned) and proportional numbers (variable-width).
  -- Fonts support these features in different ways, so it's hard to know which one to use.
  -- This might be somewhat font-dependent.
  SILE.settings:declare({
      parameter = "textsubsuper.features.number",
      type = "string",
      default = "+lnum +pnum -onum -tnum",
      help = "Font features to use for numbers in superscripts and subscripts"
    })
end

function package:registerCommands ()

  local function rescaleContent(content)
    local transformed = self.class.packages.inputfilter:transformContent(content, rescaleFilter, {
      xScale = 1,
      yScaleNumber = SILE.settings:get("textsubsuper.vscale.number"),
      yScaleOther = SILE.settings:get("textsubsuper.vscale.other"),
    })
    SILE.process(transformed)
   end

  -- REAL SUPERSCRIPT / SUBSCRIPT WHEN AVAILABLE

  self:registerCommand("textsuperscript", function (options, content)
    if type(content) ~= "table" then SU.error("Expected a table content in textsuperscript") end
    local fake = SU.boolean(options.fake, SILE.settings:get("textsubsuper.fake"))
    if fake then
      SILE.call("textsuperscript:fake", {}, content)
      return -- We are done here
    end
    if checkFontFeatures("+sups", content) then
      SILE.call("font", { features="+sups" }, content)
    else
      SU.debug("textsubsuper", "No true superscripts for '"..SU.ast.contentToString(content).."', fallback to scaling")
      SILE.call("textsuperscript:fake", {}, content)
    end
  end, "Typeset a superscript text content.")

  self:registerCommand("textsubscript", function (options, content)
    if type(content) ~= "table" then SU.error("Expected a table content in textsubscript") end
    local fake = SU.boolean(options.fake, SILE.settings:get("textsubsuper.fake"))
    if fake then
      SILE.call("textsubscript:fake", {}, content)
      return -- We are done here
    end
    if checkFontFeatures("+subs", content) then
      SILE.call("font", { features="+subs" }, content)
    elseif checkFontFeatures("+sinf", content) then
      SU.debug("textsubsuper", "No true subscripts for '"..SU.ast.contentToString(content).."', fallback to scientific inferiors")
      SILE.call("font", { features="+sinf" }, content)
    else
      SU.debug("textsubsuper", "No true subscripts for '"..SU.ast.contentToString(content).."', fallback to scaling")
      SILE.call("textsubscript:fake", {}, content)
    end
  end, "Typeset a subscript text content.")

  -- FAKE (SCALED AND RAISED) SUPERSCRIPT OR SUBSCRIPT

  self:registerCommand("textsuperscript:fake", function (_, content)
    local italicAngle = getItalicAngle()
    local weight = getWeightClass()

    local ratio = SILE.settings:get("textsubsuper.scale")
    local ySize = ratio * SILE.settings:get("font.size")
    local yOffset = SILE.settings:get("textsubsuper.offset.superscript")
    local xOffset = -math.sin(italicAngle * math.pi / 180) * yOffset
    SILE.call("kern", { width = xOffset:absolute() + SILE.types.measurement("0.1pt") })
    SILE.call("raise", { height = yOffset }, function ()
      SILE.call("font", {
        size = ySize,
        weight = weight == 400 and (weight + SILE.settings:get("textsubsuper.bolder")) or weight,
        features = SILE.settings:get("textsubsuper.features.number"),
      }, function ()
        rescaleContent(content)
      end)
    end)
    SILE.call("kern", { width = -xOffset / 2 })
  end, "Typeset a fake (raised, scaled) superscript content.")

  self:registerCommand("textsubscript:fake", function (_, content)
    local italicAngle = getItalicAngle()
    local weight = getWeightClass()

    local ratio = SILE.settings:get("textsubsuper.scale")
    local ySize = ratio * SILE.settings:get("font.size")
    local yOffset = SILE.settings:get("textsubsuper.offset.subscript")
    local xOffset = -math.sin(italicAngle * math.pi / 180) * yOffset:absolute()
    SILE.call("kern", { width = -xOffset })
    SILE.call("lower", { height = yOffset }, function ()
      SILE.call("font", {
        size = ySize,
        weight = weight == 400 and (weight + SILE.settings:get("textsubsuper.bolder")) or weight,
        features = SILE.settings:get("textsubsuper.features.number"),
      }, function ()
        rescaleContent(content)
      end)
    end)
    SILE.call("kern", { width = xOffset })
  end, "Typeset a fake (lowered, scaled) subscript content.")

end

package.documentation = [[
\begin{document}
\use[module=packages.textsubsuper]
Superscripts are sometimes needed for numbers (e.g. in footnote calls),
but also for letters (e.g. in French, century references such as
\font[features=+smcp]{xiv}\textsuperscript{e}, issue numbers such
as n\textsuperscript{os} 5–6; likewise in English, sequences such
as 14\textsuperscript{th}).
As of subscripts, chemical formulas are the most familiar example, for example
H\textsubscript{2}O or C\textsubscript{6}H\textsubscript{12}O\textsubscript{6}.

In his \em{Elements of Typographic Style} (3\textsuperscript{rd} edition, §4.3.2),
Robert Bringhurst writes: “Many fonts include sets of superscript numbers, but
these are not always of satisfactory size and design. Text numerals set at a
reduced size and elevated baseline are sometimes the best or only choice.”

Most of the time, however, assuming the font designers did their job well, such
“real” characters ought to look much better than scaled and raised characters.
SILE thrives at good typography. The \autodoc:package{textsubsuper} package
provides two commands, \autodoc:command{\textsuperscript{<content>}} and
\autodoc:command{\textsubscript{<content>}}, which aim at using these characters,
when available.

These commands achieve their goal by trying the \code{+sups} font feature for
superscripts, and the \code{+subs} or \code{+sinf} feature for subscripts.
If the output is not different than \em{without} the feature, it implies that
the corresponding OpenType feature is not supported by the font (such as the
default Gentium font, which does not have these features\footnote{Though it does
include some of the Unicode superscript and subscript characters, but this very
package does not try to address such a case.}). In that case, it relies on
scaling and raising (or lowering) the characters, so as to build “fake”
superscripts (or subscripts).

By nature, this package is \em{not} intended to work with multiple levels of
superscripts or subscripts. Also note that it tries not to mix up characters
supporting the features with those not supporting them, as it would be somewhat
ugly in most cases. Fake superscripts or subscripts will also be used if such
a case occurs.

Would you actually prefer this fake variant, the \autodoc:parameter{fake=true}
option on the above-mentioned commands enforces it. Would you want this
to be the default choice globally, the \autodoc:setting{textsubsuper.fake}
setting may also be set to true.

In his afterword, Bringhurst also notes: “It remains the case that I have
never yet tested a perfect font, no matter whether it came in the form of
foundry metal, a matrix case, a strip of film or digital information.”
In our case here, if font designers had done their job all right again,
the OpenType OS2 table could have been used to retrieve the recommended
offset, scaling and sizing parameters for a given font face. However, these
parameters are seldom properly set and they lead to a poor (not to say
utterly wrong) result for many fonts, including well-known ones…

This package therefore relies on its own settings,
\autodoc:setting{textsubsuper.scale},
\autodoc:setting{textsubsuper.offset.superscript}
and \autodoc:setting{textsubsuper.offset.subscript}.
Their default values are, by nature, empirical.

Bringhurst goes on: “In many faces, smaller numbers in semibold look better
than larger numbers of regular weight.” Hence,
the \autodoc:setting{textsubsuper.bolder} setting defaults to 200,
so that in a text in normal weight (400), superscripts and subscripts
are set in semibold (600). This setting is ignored if the input text
is not in normal weight.

Would the text be set in italic, the package relies on the italic
angle from the font properties to improve the superscript or
subscript placement.

Still, this is not sufficient to give the best possible output.
Smaller numbers are usually scaled vertically to a proportion of the
full height they would take at regular size. This is also often the case
for letters, albeit to a smaller amount.
Settings \autodoc:setting{textsubsuper.vscale.number} and
\autodoc:setting{textsubsuper.vscale.other} are thus available
to obtain that effect\footnote{This feature is currently only supported
with the \code{libtexpdf} backend.}.
Their default values, again, are obviously empirical.

The \autodoc:setting{textsubsuper.features.number} setting allows
to specify the font features to use for numbers in superscripts
and subscripts. By default, it is set to \code{+lnum +pnum -onum -tnum},
which should be a good choice for most fonts, although fonts support
these features in different ways.

\end{document}
]]

return package
