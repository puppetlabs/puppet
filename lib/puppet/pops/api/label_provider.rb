
# Provides a label for an object.
# This simple implementation calls #to_s on the given object.
class LabelProvider
  
  # Provides a label for the given object by calling `to_s` on the object.
  # The intent is for this method to be overridden in concrete label providers.
  def label o
    o.to_s
  end

  # Produces a label for the given objects type/operator with indefinite article (a/an)
  def a_an o
    text = label(o)
    "#{article(text)} #{text}"
  end

  # Produces a label for the given objects type/operator with indefinite article (A/An)
  def a_an_uc o
    text = label(o)
    "#{article(text,true)} #{text}"
  end
  
  # Produces a label for the given object with *definitie article* (the).
  def the o
    "the #{label(o)}"
  end

  # Produces a label for the given object with *definitie article* (The).
  def the_uc o
    "The #{label(o)}"
  end

  # Produces an *indefinite article* (a/an) for the given text ('a' if it starts with a vowel)
  # This is obviously flawed in the general sense as may labels have punctuation at the start and
  # this method does not translate punctuation to English words. Also, if a vowel is pronounced
  # as a consonant, the article should not be "an".
  #
  def article s, capitalize = false
    char = s[0]
    # skip an initial quote to pick first real char
    char = s[1] if char == '\'' || char == '"'
    char = char.downcase if char
    if %w{a e i o u y}.include? char
      result = "an" 
    else
      result = "a"
    end
    result = result.capitalize if capitalize
  end

end