defmodule Inflex.LineProtocol do
  @moduledoc """
  Complete implementation of the InfluxDB line protocol

  Create stats in the line protocol format from `Inflex.Point`s. The format is
  `name,tag1=tval1,...,tagN=tvalN field1=val1,...,fieldN=valN timestamp` where
  tags and timestamp are optional. There must be at least one field. If the
  timestamp is not specified, influx will use its own server's time of receipt
  as the timestamp.

  `Inflex.Point` in its typespecs defines the line protocols type system. There
  are additional rules for escaping characters that may or may not be present in a
  key or value depending on whether it is a measurement name, a tag key or
  value, or a field key or value.

  Performance and Setup Tips from the influx docs:
  1. Sort `tags` by key
  2. Use the coarsest precision possible (configured elsewhere)
  3. Use NTP to synchronize time between hosts (out of scope for this library)
  """

  @tags_and_field_keys ~r/[,=\s]/
  @field_values ~r/\"/
  @measurement_names ~r/[,\s]/

  @spec encode(point :: map() | Inflex.Point.t()) :: String.t()
  @doc """
  takes maps of well defined points and turns them into single line strings
  """
  def encode(%{} = point) do
    m_str =
      if quote_measurement?(point.measurement) do
        point.measurement
        |> escape(@measurement_names)
        |> quoted()
      else
        point.measurement
      end

    m_str
    |> with_tags(point)
    |> with_fields(point)
    |> with_timestamp(point)
  end

  defp with_tags(base, %{tags: tags}) when tags != %{} do
    Enum.join([base] ++ encode_tags(tags), ",")
  end

  defp with_tags(base, _point), do: base

  defp with_fields(base, %{fields: fields}) when fields != %{} do
    field_str =
      fields
      |> Enum.map(fn {fk, fv} ->
        k =
          fk
          |> stringify()
          |> escape(@tags_and_field_keys)

        v =
          fv
          |> stringify()
          |> escape(@field_values)
          |> quoted_value(fv)

        k <> "=" <> v
      end)
      |> Enum.join(",")

    base <> " " <> field_str
  end

  defp with_fields(_base, _point) do
    raise Inflex.FieldError
  end

  defp with_timestamp(base, %{timestamp: t}) when is_integer(t),
    do: base <> " #{t}"

  defp with_timestamp(base, _point), do: base

  defp encode_tags(tags) do
    # Since tags should be sorted consistenly with the server, it should be
    # sorted after the keys have all been stringified and escaped. This allows
    # strings and atoms to be sorted lexically.
    tags
    |> Enum.map(fn {tk, tv} ->
      {
        tk
        |> stringify()
        |> escape(@tags_and_field_keys),
        tv
        |> stringify()
        |> escape(@tags_and_field_keys)
      }
    end)
    |> Enum.sort_by(&first/1)
    |> Enum.map(fn {tk, tv} -> tk <> "=" <> tv end)
  end

  defp first(t), do: elem(t, 0)

  defp stringify(i) when is_integer(i), do: to_string(i) <> "i"
  defp stringify(v), do: to_string(v)

  defp quoted_value(s, v) when is_atom(v) or is_binary(v), do: quoted(s)
  defp quoted_value(s, _v), do: s

  defp quote_measurement?(m), do: Regex.match?(@measurement_names, m)

  defp quoted(str), do: ~s("#{str}")

  defp escape(v, reg), do: String.replace(v, reg, "\\\\\\g{0}")
end
