# Worthit appraisal contract

Worthit estimates from comparable evidence; it cannot determine an exact true
price. The versioned instructions live in
[`assets/appraisal_system_v1.txt`](../assets/appraisal_system_v1.txt), and
[`lib/domain/appraisal.dart`](../lib/domain/appraisal.dart) owns schema validation,
evidence admission, local arithmetic and report serialization.

## What version 1 does

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

Paste each source URL first, followed by its quoted sale facts, before the next
URL. Use separate blocks for readability:

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
failures produce an evidence gap, never invented data.

## Behavioral theory and safeguards

Worthit acknowledges endowment effects, anchoring, loss aversion, attachment and
urgency without assigning fixed psychological coefficients. Purchase cost,
sentiment, identity and financial pressure cannot alter local range arithmetic.
Buyers receive respectful inspection, budget and offer guidance; sellers receive
honest disclosure and proceeds-versus-waiting guidance. Neither receives
fabricated scarcity, deceptive tactics or a promised sale time.

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

`appraisalSchema()` supplies a strict JSON schema. Every declared property is
required; unknown properties and versions are rejected. Statuses are `ready`,
`needs_details`, `insufficient_evidence` and `blocked`. No model-returned numeric
range is accepted. `parseAppraisal` returns only accepted comparables and records
rejection reasons; malformed responses throw a safe `FormatException`.

Money must be finite, non-negative and within the explicit supported bound.
Dates must be real calendar dates. URLs must use HTTP(S), have no credentials,
and use a public-looking hostname. This is a link-admission check, not DNS
verification or proof of site legitimacy. Unknown/private destinations are
rejected. All text is data for Flutter rendering, not HTML or script.

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
