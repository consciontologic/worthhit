# Worthhit appraisal contract

Worthhit estimates product prices; it cannot determine an exact true price.
Only product, currency and condition are required. Notes and supported media are
optional; users do not need to supply listing excerpts. The versioned instructions live in
[`assets/appraisal_system_v2.txt`](../assets/appraisal_system_v2.txt)
(with the [legacy v1 prompt](../assets/appraisal_system_v1.txt) retained), and
[`lib/domain/appraisal.dart`](../lib/domain/appraisal.dart) owns schema validation,
evidence admission, local arithmetic and report serialization.

## Version 2 estimates

New requests use the version 2 response contract. The model researches automatically
when the user has enabled separately billed web search. It extracts real supporting
comparables when available and may supply a bounded reference estimate, condition
adjustment and uncertainty when they are not. Dart computes the displayed numbers.

A result based on sufficient admitted sales keeps the researched-comparison label.
A model-based result is explicitly **estimated**, without verified current market
sales. Reference value and adjustment are model judgments, not observed transactions;
the locally computed range must not be presented as a calibrated confidence interval.
If neither trustworthy observations nor a meaningful estimate is possible, explain
what is unknown rather than fabricate a number or demand manual evidence collection.

Currency symbols alone are ambiguous; the chosen currency code remains authoritative.
Missing location does not block a request and currency is not proof of a local market.
Notes are optional context, not instructions to override safety, provenance or prices.
Images/video can help identify condition but cannot authenticate an item, establish
an unseen defect or prove a completed transaction.

Legacy `worthit.v1` responses and saved reports remain readable. Their strict evidence
and arithmetic interpretation does not change when restored. New drafts preserve
legacy extra fields for compatibility while the homepage omits the evidence workflow.

## Researched comparables and legacy version 1

The model extracts observations and gives short explanations. The browser accepts
at least three distinct, exact-match completed sales within 90 days of the
valuation date, in the requested currency and with a consistent price basis.
It calculates their minimum, median and maximum. These are the **observed
comparable range and median**, not a calibrated confidence interval or a guaranteed
buying/selling price. Three observations and 90 days are conservative product
defaults, not universal scientific thresholds.

An observation needs the actual sold amount, ISO-style currency code, an
unambiguous `YYYY-MM-DD` sale date, and a short supporting source excerpt. Version
1 accepts limited English sale-price wording, decimal-point amounts and comma
thousands separators. Other languages, dates, currency and numeric formats may
not qualify; the parser never guesses or rewrites their meaning.

An asking price, an ended-unsold listing, a hidden accepted offer, an old sale,
an approximate product match, a different currency or an unknown delivery basis
cannot support the range. The model is instructed to compare variant, condition,
accessories and local market. Those semantic judgments are model-assisted and
may be wrong; passing the local checks does not authenticate a listing or item.

## Evidence provenance

New appraisals use provider citations gathered by optional research. The homepage
does not ask users to paste evidence. Legacy version 1 reports may contain
user-supplied evidence in the following retained format: each source URL followed
by its quoted sale facts, before the next URL.

```text
<actual public listing URL>
<verbatim excerpt establishing the sold amount, currency and date>
```

The returned URL must be present literally in the source registry. A returned
`support_quote` must be an exact substring of the evidence associated with that
URL. Provider-grounded comparables need actual citation content; a URL or title
alone is insufficient. Duplicated URLs (including common tracking variants) and
copied quotations cannot count twice. The amount must appear as an exact numeric
token next to its currency code, not merely somewhere in the text.
Use a short, unambiguous completed-sale excerpt: multiple monetary amounts
(including symbol-only amounts) or dates are rejected, and the sale statement,
amount and date must occur together in one bounded clause. Accepted syntax is
`Sold for GBP 100 on 2026-10-01` or `Sold on 2026-10-01 for GBP 100`
(also `at` instead of `for`, or currency after the amount). An explicit
`sold price: GBP 100` or `sale price: GBP 100` also qualifies with completed-sale
wording and its date in the same clause. Excerpts discussing shipping, retail,
fees, deposits, rent, tax, repair, discounts or other ancillary prices are
rejected conservatively. Sources must actually contain the literal supported
excerpt: the model must never rewrite or translate evidence to fit this grammar.
Real web snippets often lack a supported sold-price phrase or ISO date, so
research can legitimately yield no range. This is limited syntactic admission,
not universal language understanding or proof of a source's meaning or truth.

User evidence is labeled **user-supplied, not independently verified**. Provider
excerpts are labeled **provider-grounded, not independently verified**. Neither
proves that a seller told the truth, an item is authentic, or a transaction
completed. No arbitrary-page browser fetch is required. Search or citation
failures leave a visible research gap. Version 2 can fall back to a clearly labeled
model estimate; neither protocol invents comparable data.

## Behavioral theory and safeguards

Worthit acknowledges endowment effects, anchoring, loss aversion, attachment and
urgency without assigning fixed psychological coefficients. Purchase cost,
sentiment, identity and financial pressure cannot alter local range arithmetic.
A single neutral appraisal explains product worth, condition, evidence gaps and
observable transaction safeguards regardless of whether the person buys or sells.
The model must not choose a trading side or recommend role-specific negotiation
tactics, fabricated scarcity, deception or a promised sale time.

Trust is discussed through observable safeguards: inspection, ownership evidence,
payment protection, delivery and written terms. Identity, friendliness and
familiarity are not proof of honesty.

Inflation, FX, popularity and demand require relevant dated evidence. Broad
inflation must not be applied mechanically to an individual used item or counted
again when recent local sales already reflect current conditions. Version 1
admits same-currency comparables only; unsupported conversions are excluded.

Pornography, drugs/medicines, weapons, stolen/counterfeit/illegal goods,
confidential documents, credentials, personal data and unsafe/recalled items
are outside the scope. A local normalized keyword filter catches obvious cases;
the model must classify context too. Neither layer is a universal safety or
legality classifier. Ambiguity should lead to clarification or abstention.
No uploaded or generated content is executed.

## Contract and failure behavior

`appraisalSchema()` supplies a strict version 2 JSON schema. Every declared property
is required; unknown properties and versions are rejected. New live replies must
use version 2. The parser also accepts version 1 for legacy data. Statuses include
`ready`, `needs_details`, `insufficient_evidence` and `blocked`; version 2 adds the
distinct `estimated` status and structured assumptions from which Dart calculates
a range. No model-returned numeric range is accepted. `parseAppraisal` returns only accepted comparables and records
rejection reasons; malformed responses throw a safe `FormatException`.

Money must be finite, non-negative and within the explicit supported bound.
Dates must be real calendar dates. URLs must use HTTP(S), have no credentials,
and use a public-looking hostname. This is a link-admission check, not DNS
verification or proof of site legitimacy. Unknown/private destinations are
rejected. All text is data for Flutter rendering, not HTML or script.

Current inputs contain no buy/sell goal. Strictly valid legacy inputs with a
`buy` or `sell` goal remain readable; decoding discards that field. Canonical
saving, report matching and provider prompts use the neutral input shape, without
changing storage keys or historical report protocol identifiers.

Saved reports round-trip through validated JSON and are historical observations.
They must not be presented as freshly researched after restoration. The input
includes its valuation date; a new appraisal uses the current requested date.
`AppraisalInput.copyWith(askingPrice: null)` clears the optional asking-price
anchor; omitting it preserves the existing value.

## Evaluation

`test/domain/` exercises strict schemas, storage integrity, malicious source
boundaries, fabricated excerpts, URL provenance, monetary tokens, date and
currency mismatch, duplicates, asking-versus-sold distinctions, safety
exclusions, harmless keyword collisions, and deterministic odd/even medians.
All `example.com` listings and prices in those tests are explicitly synthetic.

Paired fixtures establish that purchase anchors, sentimental attachment and
urgency cannot change the calculated range. These tests validate code behavior,
not live model accuracy. Live-provider evaluation is separate and bounded:
check prohibited-item refusal, source support and correct abstention before
assessing price predictions against held-out completed transactions. A fluent
response or a passing JSON test is not evidence of valuation accuracy.

## Primary sources

Reviewed 2026-10-20. The contract's engineering thresholds are product choices;
these sources support the distinctions and limitations, not those thresholds.

- [eBay Product Research](https://www.ebay.com/help/selling/selling-tools/research?id=4853)
  distinguishes actual accepted-offer sale prices from less-complete listing
  results.
- [Nobel account of Thaler's work](https://www.nobelprize.org/prizes/economic-sciences/2017/press-release/)
  describes ownership effects and loss aversion;
  [Kahneman's account](https://www.nobelprize.org/prizes/economic-sciences/2002/kahneman/biographical/)
  discusses judgment and anchoring.
- [BLS CPI methodology](https://www.bls.gov/cpi/questions-and-answers.htm)
  explains that CPI measures a representative basket, not an individual item's
  price path.
- [ECB exchange-rate methodology](https://data.ecb.europa.eu/methodology/exchange-rates)
  describes dated reference rates and their purpose.
- [FTC marketplace guidance](https://consumer.ftc.gov/articles/buying-online-marketplace)
  supports concrete checks on item condition, payment and marketplace terms.
- [CPSC resale guidance](https://www.cpsc.gov/FAQ/Online-Sellers-Safety-Guide-FAQs)
  addresses unsafe and recalled secondhand products in the United States;
  other markets require applicable local sources.
- [OpenRouter structured outputs](https://openrouter.ai/docs/guides/features/structured-outputs),
  [web search server tool](https://openrouter.ai/docs/guides/features/server-tools/web-search),
  and [citation metadata and search costs](https://openrouter.ai/docs/guides/features/plugins/web-search)
  document the transport contract. Search may cost extra even with free inference;
  enabling a search tool does not establish that it ran or found usable evidence.
