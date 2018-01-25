defmodule ExFlux.LineProtocolTest do
  use ExUnit.Case

  alias ExFlux.LineProtocol, as: LP

  describe "encode/1" do
    test "basic encoding" do
      point = %{
        measurement: "test",
        fields: %{"key" => "value"}
      }

      expected = ~s(test key="value")

      assert LP.encode(point) == expected
    end

    test "no fields provided" do
      assert_raise ExFlux.FieldError, fn ->
        LP.encode(%{measurement: "test"})
      end
    end

    test "integer fields" do
      point = %{
        measurement: "test",
        fields: %{
          "integer" => 1
        }
      }

      expected = "test integer=1i"

      assert LP.encode(point) == expected
    end

    test "float fields" do
      point = %{
        measurement: "test",
        fields: %{
          "float_1" => 1.0,
          "float_2" => 1.0e-10
        }
      }

      expected = "test float_1=1.0,float_2=1.0e-10"

      assert LP.encode(point) == expected
    end

    test "with_tags" do
      point = %{
        measurement: "test",
        fields: %{
          "value" => 1
        },
        tags: %{
          :tag0 => "val0",
          "tag1" => "val1",
          :tag2 => "val2",
          "tagN" => :valN
        }
      }

      expected = ~s(test,tag0=val0,tag1=val1,tag2=val2,tagN=valN value=1i)

      assert LP.encode(point) == expected
    end

    test "with_timestamp" do
      now = System.os_time(:nanosecond)

      point = %{
        measurement: "test",
        fields: %{
          "value" => 1
        },
        tags: %{
          "tag0" => "val0"
        },
        timestamp: now
      }

      expected = ~s(test,tag0=val0 value=1i ) <> to_string(now)

      assert LP.encode(point) == expected
    end

    test "escaping" do
      point = %{
        measurement: "measurement with quo⚡es, and emoji",
        fields: %{
          "field_k\\ey" => ~s(string field value, only " need be esc🔍ped)
        },
        tags: %{
          "tag key with sp🚀ces" => ~s(tag,value,with"commas")
        }
      }

      expected =
        ~s("measurement\\ with\\ quo⚡es\\,\\ and\\ emoji") <>
          ~s(,tag\\ key\\ with\\ sp🚀ces=tag\\,value\\,with"commas" ) <>
          ~s(field_k\\ey="string field value, only \\\" need be esc🔍ped")

      assert LP.encode(point) == expected
    end
  end
end
