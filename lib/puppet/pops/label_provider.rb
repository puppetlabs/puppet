# Provides a label for an object.
# This simple implementation calls #to_s on the given object, and handles articles 'a/an/the'.
#
module Puppet::Pops::LabelProvider
  VOWELS = %w{a e i o u y}
  SKIPPED_CHARACTERS = %w{" '}
  A = "a"
  AN = "an"

  # Provides a label for the given object by calling `to_s` on the object.
  # The intent is for this method to be overridden in concrete label providers.
  def label o
    o.to_s
  end

  # Produces a label for the given text with indefinite article (a/an)
  def a_an o
    text = label(o)
    "#{article(text)} #{text}"
  end

  # Produces a label for the given text with indefinite article (A/An)
  def a_an_uc o
    text = label(o)
    "#{article(text).capitalize} #{text}"
  end

  # Produces a label for the given text with *definitie article* (the).
  def the o
    "the #{label(o)}"
  end

  # Produces a label for the given text with *definitie article* (The).
  def the_uc o
    "The #{label(o)}"
  end

  # Appends 's' to (optional) text if count != 1 else an empty string
  def plural_s(count, text = '')
    count == 1 ? text : "#{text}s"
  end

  private

  # Produces an *indefinite article* (a/an) for the given text ('a' if
  # it starts with a vowel) This is obviously flawed in the general
  # sense as may labels have punctuation at the start and this method
  # does not translate punctuation to English words. Also, if a vowel is
  # pronounced as a consonant, the article should not be "an".
  #
  def article s
    article_for_letter(first_letter_of(s))
  end

  def first_letter_of(string)
    char = string[0,1]
    if SKIPPED_CHARACTERS.include? char
      char = string[1,1]
    end

    if char == ""
      raise Puppet::DevError, "<#{string}> does not appear to contain a word"
    end

    char
  end

  def article_for_letter(letter)
    downcased = letter.downcase
    if VOWELS.include? downcased
      AN
    else
      A
    end
  end
end
